import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bike_model.dart';
import '../models/user_model.dart';
import '../providers/bike_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'bike_brand_selection_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    final displayName = (currentUser?.name.isNotEmpty == true)
        ? currentUser!.name
        : 'Unknown User';
    final displayEmail = (currentUser?.email.isNotEmpty == true)
        ? currentUser!.email
        : 'No email';
    final displayPhone = (currentUser?.phone.isNotEmpty == true)
        ? currentUser!.phone
        : 'No phone';

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Profile Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.themedCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.orange, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.orangeGlow,
                      border: Border.all(color: AppColors.orange, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.orange,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayEmail,
                    style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orangeGlow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      '👑 LEADER',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Profile Information ───────────────────────────────────────────
            Text(
              'Profile Information',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            _ProfileInfoTile(
              icon: Icons.email_outlined,
              title: 'Email',
              value: displayEmail,
              onTap: () =>
                  _showEditFieldDialog(context, 'Email', displayEmail, (value) {
                    if (currentUser != null) {
                      context.read<AuthProvider>().updateCurrentUser(
                        UserModel(
                          name: currentUser.name,
                          email: value,
                          phone: currentUser.phone,
                          password: currentUser.password,
                          bikeStatus: currentUser.bikeStatus,
                          bikeBrand: currentUser.bikeBrand,
                          bikeModel: currentUser.bikeModel,
                          bikeCc: currentUser.bikeCc,
                          bikeYear: currentUser.bikeYear,
                          bikeRegistration: currentUser.bikeRegistration,
                        ),
                      );
                    }
                  }),
            ),
            const SizedBox(height: 12),
            _ProfileInfoTile(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: displayPhone,
              onTap: () =>
                  _showEditFieldDialog(context, 'Phone', displayPhone, (value) {
                    if (currentUser != null) {
                      context.read<AuthProvider>().updateCurrentUser(
                        UserModel(
                          name: currentUser.name,
                          email: currentUser.email,
                          phone: value,
                          password: currentUser.password,
                          bikeStatus: currentUser.bikeStatus,
                          bikeBrand: currentUser.bikeBrand,
                          bikeModel: currentUser.bikeModel,
                          bikeCc: currentUser.bikeCc,
                          bikeYear: currentUser.bikeYear,
                          bikeRegistration: currentUser.bikeRegistration,
                        ),
                      );
                    }
                  }),
            ),

            const SizedBox(height: 24),

            // ─── Your Bikes ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Bikes',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddBikeDialog(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add,
                          color: AppColors.themedBackground,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.themedBackground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bikes List
            Consumer<BikeProvider>(
              builder: (context, bikeProvider, _) {
                final bikes = bikeProvider.bikes;

                if (bikes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.two_wheeler_outlined,
                            size: 48,
                            color: AppColors.themedGrey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No bikes added yet',
                            style: TextStyle(
                              color: AppColors.themedGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const AddBikeDialog(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Add Your First Bike',
                              style: TextStyle(
                                color: AppColors.themedBackground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: bikes.map((bike) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BikeCard(
                        bike: bike,
                        isActive: bikeProvider.activeBike?.id == bike.id,
                        onTap: () {
                          bikeProvider.setActiveBike(bike);
                        },
                        onDelete: () {
                          bikeProvider.removeBike(bike.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bike "${bike.name}" removed'),
                              backgroundColor: AppColors.orange,
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Ride Statistics ───────────────────────────────────────────────
            Text(
              'Ride Statistics',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.directions_run_outlined,
                    title: 'Total Rides',
                    value: '24',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.space_bar,
                    title: 'Total KM',
                    value: '2840',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.access_time_outlined,
                    title: 'Ride Hours',
                    value: '156h',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.groups_outlined,
                    title: 'Groups Led',
                    value: '8',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Action Buttons ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.themedText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.orange, width: 1.2),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.themedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.themedText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditFieldDialog(
    BuildContext context,
    String fieldName,
    String currentValue,
    Function(String) onSave,
  ) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.orange, width: 1.2),
        ),
        title: Text(
          'Edit $fieldName',
          style: const TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.themedText),
          decoration: InputDecoration(
            hintText: 'Enter $fieldName',
            hintStyle: TextStyle(color: AppColors.themedGrey),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.themedGreyBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            filled: true,
            fillColor: AppColors.themedCard,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.themedText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onSave(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final nameCtrl = TextEditingController(text: currentUser?.name ?? '');
    final emailCtrl = TextEditingController(text: currentUser?.email ?? '');
    final phoneCtrl = TextEditingController(text: currentUser?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.orange, width: 1.2),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name Field
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: AppColors.themedGrey),
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.themedGreyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.themedCard,
                ),
              ),
              const SizedBox(height: 16),

              // Email Field
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: AppColors.themedGrey),
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.themedGreyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.themedCard,
                ),
              ),
              const SizedBox(height: 16),

              // Phone Field
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: AppColors.themedGrey),
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.themedGreyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.themedCard,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.themedText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty &&
                  emailCtrl.text.trim().isNotEmpty &&
                  phoneCtrl.text.trim().isNotEmpty) {
                if (currentUser != null) {
                  context.read<AuthProvider>().updateCurrentUser(
                    UserModel(
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      password: currentUser.password,
                      bikeStatus: currentUser.bikeStatus,
                      bikeBrand: currentUser.bikeBrand,
                      bikeModel: currentUser.bikeModel,
                      bikeCc: currentUser.bikeCc,
                      bikeYear: currentUser.bikeYear,
                      bikeRegistration: currentUser.bikeRegistration,
                    ),
                  );
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Profile updated successfully!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text(
              'Save Changes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.themedGreyBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.themedGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.themedGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhoneTile extends StatelessWidget {
  final String phone;
  final bool isVerified;
  final VoidCallback onTap;

  const _ProfilePhoneTile({
    required this.phone,
    required this.isVerified,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.themedGreyBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_outlined,
                color: AppColors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Phone',
                        style: TextStyle(
                          color: AppColors.themedGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green, width: 0.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange,
                              width: 0.5,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.themedGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.themedGreyBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.themedGrey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bike Card ───────────────────────────────────────────────────────────────
class _BikeCard extends StatelessWidget {
  final Bike bike;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BikeCard({
    required this.bike,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppColors.orange
                : AppColors.orange.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bike.brand.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bike.name,
                              style: TextStyle(
                                color: AppColors.themedText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bike.brand.displayName,
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.orange, width: 1),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (bike.model != null) ...[
                  Icon(
                    Icons.info_outline,
                    color: AppColors.themedGrey.withValues(alpha: 0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    bike.model!,
                    style: TextStyle(
                      color: AppColors.themedGrey.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (bike.licensePlate != null) ...[
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.themedGrey.withValues(alpha: 0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    bike.licensePlate!,
                    style: TextStyle(
                      color: AppColors.themedGrey.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (bike.yearOfPurchase != null) ...[
                  Icon(
                    Icons.calendar_today,
                    color: AppColors.themedGrey.withValues(alpha: 0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${bike.yearOfPurchase}',
                    style: TextStyle(
                      color: AppColors.themedGrey.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            if (bike.color != null || bike.engineCapacity != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (bike.color != null) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _parseColor(bike.color!),
                        border: Border.all(
                          color: AppColors.themedGrey.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      bike.color!,
                      style: TextStyle(
                        color: AppColors.themedGrey.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (bike.engineCapacity != null)
                    Text(
                      '${bike.engineCapacity!.toStringAsFixed(0)} cc',
                      style: TextStyle(
                        color: AppColors.themedGrey.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorName) {
    final name = colorName.toLowerCase();
    if (name.contains('red')) return Colors.red;
    if (name.contains('black')) return AppColors.themedText;
    if (name.contains('white')) return Colors.white;
    if (name.contains('blue')) return Colors.blue;
    if (name.contains('green')) return Colors.green;
    if (name.contains('yellow')) return Colors.yellow;
    if (name.contains('grey') || name.contains('gray')) {
      return AppColors.themedGrey;
    }
    if (name.contains('orange')) return Colors.orange;
    if (name.contains('purple')) return Colors.purple;
    if (name.contains('chrome') || name.contains('silver')) {
      return AppColors.themedGrey;
    }
    return AppColors.orange;
  }
}
