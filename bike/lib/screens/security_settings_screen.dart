import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart' as app_auth;
import '../theme/app_theme.dart';
import '../utils/password_validator.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _showMessage('Password changes are unavailable for this account.');
      return;
    }

    setState(() => _saving = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('Password changed successfully.');
    } on FirebaseAuthException catch (error) {
      _showMessage(switch (error.code) {
        'wrong-password' || 'invalid-credential' =>
          'The current password is incorrect.',
        'weak-password' => 'Choose a stronger password and try again.',
        'requires-recent-login' => 'Sign in again before changing your password.',
        _ => error.message ?? 'Unable to change password. Please try again.',
      });
    } catch (_) {
      _showMessage('Unable to change password. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<app_auth.AuthProvider>().currentUser;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email ?? account?.email ?? 'No email available';
    final providers = firebaseUser?.providerData
            .map((provider) => provider.providerId == 'password'
                ? 'Email and password'
                : provider.providerId)
            .toSet()
            .join(', ') ??
        'Local account';

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SecurityCard(
            title: 'Security details',
            children: [
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Account email',
                value: email,
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Icons.verified_user_outlined,
                label: 'Sign-in method',
                value: providers,
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Icons.lock_outline,
                label: 'Password',
                value: firebaseUser?.providerData.any(
                          (provider) => provider.providerId == 'password',
                        ) ==
                        true
                    ? 'Set for this account'
                    : 'Managed by your sign-in provider',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SecurityCard(
            title: 'Change password',
            children: [
              if (firebaseUser?.providerData.any(
                    (provider) => provider.providerId == 'password',
                  ) !=
                  true)
                Text(
                  'This account does not use an email password. Manage its password with your sign-in provider.',
                  style: TextStyle(color: AppColors.themedGrey),
                )
              else ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _PasswordField(
                        controller: _currentPasswordController,
                        label: 'Current password',
                        obscureText: _obscureCurrent,
                        onToggleVisibility: () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your current password.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        controller: _newPasswordController,
                        label: 'New password',
                        obscureText: _obscureNew,
                        onToggleVisibility: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        validator: (value) => validatePassword(value ?? ''),
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        controller: _confirmPasswordController,
                        label: 'Confirm new password',
                        obscureText: _obscureConfirm,
                        onToggleVisibility: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        validator: (value) =>
                            value != _newPasswordController.text
                                ? 'Passwords do not match.'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _changePassword,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_reset),
                          label: Text(
                            _saving ? 'Updating password...' : 'Update password',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Use at least 8 characters, including an uppercase letter and a number.',
                    style: TextStyle(
                      color: AppColors.themedGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.themedCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.themedGreyBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.orange),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.themedGrey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppColors.themedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    validator: validator,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: obscureText ? 'Show password' : 'Hide password',
        onPressed: onToggleVisibility,
        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
