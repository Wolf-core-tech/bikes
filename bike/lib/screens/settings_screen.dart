import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_photo.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import 'security_settings_screen.dart';
import 'settings_category_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _ProfileCard(
            name: user?.name.isNotEmpty == true ? user!.name : 'Rider',
            email: user?.email.isNotEmpty == true
                ? user!.email
                : 'No email added',
            phone: user?.phone ?? '',
            bio: user?.bio ?? '',
            photoUrl: user?.photoUrl,
            photoPath: user?.photoPath,
            onTap: () => _push(context, const ProfileScreen()),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('YOUR ACCOUNT'),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            description: 'Photo, personal details and bio',
            onTap: () => _push(context, const ProfileScreen()),
          ),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.shield_outlined,
            title: 'Security & privacy',
            description: 'Password and account security',
            onTap: () => _push(context, const SecuritySettingsScreen()),
          ),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            description: 'Push alerts, sound and vibration',
            onTap: () => _push(context, const NotificationSettingsScreen()),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('APP'),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.tune_rounded,
            title: 'App preferences',
            description: 'Theme, language and display',
            onTap: () => _push(context, const PreferencesSettingsScreen()),
          ),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.storage_outlined,
            title: 'Storage & permissions',
            description: 'Cache, downloads and device access',
            onTap: () => _push(context, const StorageSettingsScreen()),
          ),
          const SizedBox(height: 10),
          _CategoryCard(
            icon: Icons.help_outline_rounded,
            title: 'Support & about',
            description: 'Help, policies and app information',
            onTap: () => _push(context, const SupportSettingsScreen()),
          ),
          const SizedBox(height: 24),
          _CategoryCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Account management',
            description: 'Log out or permanently delete your account',
            onTap: () => _push(context, const AccountManagementScreen()),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'BIKE SQUAD  ·  VERSION 1.0.0',
              style: TextStyle(
                color: AppColors.themedGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget page) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );

  static Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static Future<void> _confirmDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final requiresPassword =
        user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
    final passwordController = TextEditingController();
    final result = await showDialog<({bool confirmed, String? password})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.themedSurface,
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your sign-in and personal profile. Shared content such as messages, squads and ride history may remain visible to others. This action cannot be undone.',
              ),
              if (requiresPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm your password',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: requiresPassword && passwordController.text.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, (
                      confirmed: true,
                      password: requiresPassword
                          ? passwordController.text
                          : null,
                    )),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
    if (result?.confirmed != true || !context.mounted) return;

    try {
      await context.read<AuthProvider>().deleteAccount(
        password: result?.password,
      );
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      final message = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' => 'The password is incorrect.',
        'requires-recent-login' =>
          'Sign in again before deleting your account.',
        _ => error.message ?? 'Could not delete the account.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete the account: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.themedBackground,
    appBar: AppBar(title: const Text('Account management')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _CategoryCard(
          icon: Icons.logout_rounded,
          title: 'Log out',
          description: 'Sign out of this device',
          iconColor: AppColors.themedGrey,
          onTap: () => SettingsScreen._confirmLogout(context),
        ),
        const SizedBox(height: 12),
        _CategoryCard(
          icon: Icons.delete_outline_rounded,
          title: 'Delete account',
          description: 'Permanently remove your account and profile',
          destructive: true,
          onTap: () => SettingsScreen._confirmDeleteAccount(context),
        ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.bio,
    required this.photoUrl,
    required this.photoPath,
    required this.onTap,
  });

  final String name;
  final String email;
  final String phone;
  final String bio;
  final String? photoUrl;
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.themedCard,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            ProfilePhoto(photoUrl: photoUrl, photoPath: photoPath, size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      email,
                      if (phone.isNotEmpty) phone,
                      if (bio.isNotEmpty) bio,
                    ].join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: AppColors.orange,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: AppColors.themedGrey,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.iconColor,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.danger
        : iconColor ?? AppColors.orange;
    return Material(
      color: AppColors.themedCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: destructive ? color : AppColors.themedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.themedGrey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
