import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import '../models/user_model.dart';
import '../models/bike_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bike_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/bike_brand_selector.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Bike details controllers
  final _bikeModelController = TextEditingController();
  final _bikeCcController = TextEditingController();
  final _bikeYearController = TextEditingController();
  final _bikeRegistrationController = TextEditingController();

  bool _obscurePassword = true;
  String _bikeStatus = 'Don\'t have bike'; // Default selection
  String? _selectedBikeBrand;

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all mandatory personal details (Name, Email, Phone, Password).',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_bikeStatus == 'Have bike') {
      final model = _bikeModelController.text.trim();
      final cc = _bikeCcController.text.trim();
      final year = _bikeYearController.text.trim();
      final reg = _bikeRegistrationController.text.trim();

      if (_selectedBikeBrand == null ||
          model.isEmpty ||
          cc.isEmpty ||
          year.isEmpty ||
          reg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all mandatory bike specifications.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final newUser = UserModel(
      name: name,
      email: email,
      phone: phone,
      password: password,
      bikeStatus: _bikeStatus,
      bikeBrand: _bikeStatus == 'Have bike' ? _selectedBikeBrand : null,
      bikeModel: _bikeStatus == 'Have bike'
          ? _bikeModelController.text.trim()
          : null,
      bikeCc: _bikeStatus == 'Have bike' ? _bikeCcController.text.trim() : null,
      bikeYear: _bikeStatus == 'Have bike'
          ? _bikeYearController.text.trim()
          : null,
      bikeRegistration: _bikeStatus == 'Have bike'
          ? _bikeRegistrationController.text.trim()
          : null,
    );

    try {
      await context.read<AuthProvider>().registerUser(newUser);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to create this account.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Add bike to BikeProvider if user registered a bike
    if (_bikeStatus == 'Have bike' && mounted) {
      final bikeBrandText = _selectedBikeBrand!;
      final bikeModelText = _bikeModelController.text.trim();
      context.read<BikeProvider>().addBike(
        Bike(
          id: 'bike_${DateTime.now().millisecondsSinceEpoch}',
          name: '$bikeBrandText $bikeModelText',
          brand: bikeBrandFromRegistrationName(bikeBrandText),
          model: bikeModelText,
          yearOfPurchase: int.tryParse(_bikeYearController.text.trim()) ?? 2023,
          licensePlate: _bikeRegistrationController.text.trim(),
          color: 'Red & Black',
          engineCapacity:
              double.tryParse(_bikeCcController.text.trim()) ?? 150.0,
        ),
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration successful! A verification link has been sent to your email. Please verify before signing in.',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LoginScreen(prefilledEmail: email, prefilledPassword: password),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bikeModelController.dispose();
    _bikeCcController.dispose();
    _bikeYearController.dispose();
    _bikeRegistrationController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.themedText),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.themedGrey),
          prefixIcon: Icon(icon, color: const Color(0xFFE63946)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.themedCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.themedGreyBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.themedGreyBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE63946), width: 2),
          ),
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Red & Black Header
            AuthHeader(
              title: 'Join The Squad',
              subtitle: 'Create your rider profile and gear up for group rides',
              badgeText: 'RIDER SIGNUP',
              showBackButton: true,
              onBackTap: () => Navigator.pop(context),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Info',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.themedText,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name *',
                    icon: Icons.person_outline,
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address *',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number *',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password *',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.themedGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.two_wheeler,
                        color: Color(0xFFE63946),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bike Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.themedText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Dropdown for Bike Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.themedCard,
                      border: Border.all(color: AppColors.themedGreyBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _bikeStatus,
                        isExpanded: true,
                        dropdownColor: AppColors.themedCard,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFFE63946),
                        ),
                        style: TextStyle(
                          color: AppColors.themedText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _bikeStatus = newValue;
                            });
                          }
                        },
                        items: <String>['Have bike', 'Don\'t have bike']
                            .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Conditional Bike Details
                  if (_bikeStatus == 'Have bike') ...[
                    Text(
                      'Bike Specification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.themedText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BikeBrandSelector(
                      selectedBrand: _selectedBikeBrand,
                      onSelected: (brand) => setState(() {
                        _selectedBikeBrand = brand;
                      }),
                    ),
                    _buildTextField(
                      controller: _bikeModelController,
                      label: 'Bike Model * (e.g., R15, CBR 250R)',
                      icon: Icons.speed,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _bikeCcController,
                            label: 'Engine CC *',
                            icon: Icons.flash_on,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _bikeYearController,
                            label: 'Year *',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _bikeRegistrationController,
                      label: 'Registration Number *',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Red & Black Gradient Register Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE63946), Color(0xFF900C3F)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE63946,
                          ).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _register,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'COMPLETE REGISTER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: AppColors.themedText,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFFE63946),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
