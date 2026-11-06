import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/bike_model.dart';
import '../models/bike_model_catalog.dart';
import '../models/profile_health_details.dart';
import '../models/user_model.dart';
import '../providers/bike_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/indian_phone_number.dart';
import '../utils/profile_photo_validation.dart';
import '../widgets/bike_brand_logo.dart';
import '../widgets/profile_photo.dart';
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
    final healthDetails = authProvider.profileHealthDetails;

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
                  _ProfilePhotoPicker(
                    photoUrl: currentUser?.photoUrl,
                    photoPath: currentUser?.photoPath,
                    compact: true,
                    displayName: displayName,
                    displayEmail: displayEmail,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Personal Information',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileInfoTile(
              icon: Icons.notes_outlined,
              title: 'Bio',
              value: currentUser?.bio.isNotEmpty == true
                  ? currentUser!.bio
                  : 'Add a short bio',
              onTap: () => _showEditFieldDialog(
                context,
                'Bio',
                currentUser?.bio ?? '',
                (value) {
                  if (currentUser != null) {
                    context.read<AuthProvider>().updateCurrentUser(
                      currentUser.copyWith(bio: value),
                    );
                  }
                },
              ),
            ),
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
                          bio: currentUser.bio,
                          email: value,
                          phone: currentUser.phone,
                          password: currentUser.password,
                          bikeStatus: currentUser.bikeStatus,
                          bikeBrand: currentUser.bikeBrand,
                          bikeModel: currentUser.bikeModel,
                          bikeCc: currentUser.bikeCc,
                          bikeVehicleType: currentUser.bikeVehicleType,
                          bikeYear: currentUser.bikeYear,
                          bikeRegistration: currentUser.bikeRegistration,
                          photoUrl: currentUser.photoUrl,
                        ),
                      );
                    }
                  }),
            ),
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
                          bio: currentUser.bio,
                          email: currentUser.email,
                          phone: value,
                          password: currentUser.password,
                          bikeStatus: currentUser.bikeStatus,
                          bikeBrand: currentUser.bikeBrand,
                          bikeModel: currentUser.bikeModel,
                          bikeCc: currentUser.bikeCc,
                          bikeVehicleType: currentUser.bikeVehicleType,
                          bikeYear: currentUser.bikeYear,
                          bikeRegistration: currentUser.bikeRegistration,
                          photoUrl: currentUser.photoUrl,
                        ),
                      );
                    }
                  }),
            ),
            _ProfileInfoTile(
              icon: Icons.cake_outlined,
              title: 'Date of birth',
              value: healthDetails.dateOfBirth == null
                  ? 'Add date of birth'
                  : _formatDateOfBirth(healthDetails.dateOfBirth!),
              onTap: () => _pickDateOfBirth(context, healthDetails),
              trailing: _visibilityDropdown(
                healthDetails.dateOfBirthVisibility,
                (visibility) => _updateHealthDetails(
                  healthDetails.copyWith(dateOfBirthVisibility: visibility),
                ),
              ),
            ),
            _ProfileInfoTile(
              icon: Icons.bloodtype_outlined,
              title: 'Blood group',
              value: healthDetails.bloodGroup ?? 'Add blood group',
              onTap: () => _showBloodGroupPicker(context, healthDetails),
              trailing: Text(
                'Everyone',
                style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
              ),
            ),
            _ProfileInfoTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Health issue',
              value: healthDetails.healthIssue ?? 'Add health issue',
              onTap: () => _showEditFieldDialog(
                context,
                'Health issue',
                healthDetails.healthIssue ?? '',
                (value) => _updateHealthDetails(
                  healthDetails.copyWith(
                    healthIssue: value,
                    clearHealthIssue: value.isEmpty,
                  ),
                ),
                allowEmpty: true,
                maxLines: 3,
              ),
              trailing: _visibilityDropdown(
                healthDetails.healthIssueVisibility,
                (visibility) => _updateHealthDetails(
                  healthDetails.copyWith(healthIssueVisibility: visibility),
                ),
              ),
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
                        onEdit:
                            BikeModelCatalog.brandNameFor(bike.brand) != null &&
                                BikeModelCatalog.find(
                                      BikeModelCatalog.brandNameFor(
                                        bike.brand,
                                      )!,
                                      bike.model ?? '',
                                    ) !=
                                    null
                            ? () => showDialog<void>(
                                context: context,
                                builder: (_) => AddBikeDialog(bike: bike),
                              )
                            : null,
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
                  side: BorderSide(color: AppColors.orange),
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
          side: BorderSide(color: AppColors.orange, width: 1.2),
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
    Function(String) onSave, {
    bool allowEmpty = false,
    int maxLines = 1,
  }) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.orange, width: 1.2),
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
          maxLines: maxLines,
          maxLength: fieldName == 'Health issue' ? 500 : null,
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
              borderSide: BorderSide(color: AppColors.orange, width: 1.5),
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
              if (ctrl.text.trim().isNotEmpty ||
                  allowEmpty ||
                  fieldName == 'Bio') {
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

  Widget _visibilityDropdown(
    ProfileFieldVisibility visibility,
    ValueChanged<ProfileFieldVisibility> onChanged,
  ) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<ProfileFieldVisibility>(
        value: visibility,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.orange),
        items: ProfileFieldVisibility.values
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option.label,
                  style: TextStyle(color: AppColors.themedText, fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Future<void> _updateHealthDetails(ProfileHealthDetails details) async {
    try {
      await context.read<AuthProvider>().updateProfileHealthDetails(details);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update health details: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _pickDateOfBirth(
    BuildContext context,
    ProfileHealthDetails details,
  ) async {
    final today = DateTime.now();
    final parsed = DateTime.tryParse(details.dateOfBirth ?? '');
    final initialDate =
        parsed != null && parsed.year >= 1900 && !parsed.isAfter(today)
        ? parsed
        : DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select date of birth',
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await _updateHealthDetails(details.copyWith(dateOfBirth: value));
  }

  Future<void> _showBloodGroupPicker(
    BuildContext context,
    ProfileHealthDetails details,
  ) async {
    const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.themedSurface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final group in bloodGroups)
              ListTile(
                title: Text(group),
                trailing: details.bloodGroup == group
                    ? const Icon(Icons.check, color: AppColors.orange)
                    : null,
                onTap: () => Navigator.pop(sheetContext, group),
              ),
            ListTile(
              title: const Text('Clear blood group'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _updateHealthDetails(
      details.copyWith(bloodGroup: selected, clearBloodGroup: selected.isEmpty),
    );
  }

  String _formatDateOfBirth(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showEditProfileDialog(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final nameCtrl = TextEditingController(text: currentUser?.name ?? '');
    final emailCtrl = TextEditingController(text: currentUser?.email ?? '');
    final bioCtrl = TextEditingController(text: currentUser?.bio ?? '');
    final phoneCtrl = TextEditingController(
      text: indianPhoneNumberDigits(currentUser?.phone ?? ''),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.orange, width: 1.2),
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
              _ProfilePhotoPicker(
                photoUrl: currentUser?.photoUrl,
                photoPath: currentUser?.photoPath,
              ),
              const SizedBox(height: 20),

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
                inputFormatters: [IndianPhoneNumberFormatter()],
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixText: '+91',
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
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                maxLength: 160,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell your squad a little about yourself',
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
                if (!isValidIndianPhoneNumber(phoneCtrl.text.trim())) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid 10-digit phone number after +91.',
                      ),
                      backgroundColor: AppColors.orange,
                    ),
                  );
                  return;
                }
                if (currentUser != null) {
                  context.read<AuthProvider>().updateCurrentUser(
                    UserModel(
                      name: nameCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      phone: toIndianPhoneNumber(phoneCtrl.text.trim()),
                      password: currentUser.password,
                      bikeStatus: currentUser.bikeStatus,
                      bikeBrand: currentUser.bikeBrand,
                      bikeModel: currentUser.bikeModel,
                      bikeCc: currentUser.bikeCc,
                      bikeVehicleType: currentUser.bikeVehicleType,
                      bikeYear: currentUser.bikeYear,
                      bikeRegistration: currentUser.bikeRegistration,
                      photoUrl: currentUser.photoUrl,
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

class _ProfilePhotoPicker extends StatefulWidget {
  const _ProfilePhotoPicker({
    required this.photoUrl,
    this.photoPath,
    this.compact = false,
    this.displayName,
    this.displayEmail,
  });

  final String? photoUrl;
  final String? photoPath;
  final bool compact;
  final String? displayName;
  final String? displayEmail;

  @override
  State<_ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<_ProfilePhotoPicker> {
  final _imagePicker = ImagePicker();
  bool _isBusy = false;
  bool _isManaging = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _photoUrl;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.photoUrl;
    _photoPath = widget.photoPath;
    if (defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
    }
  }

  @override
  void didUpdateWidget(covariant _ProfilePhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.photoPath != widget.photoPath) {
      _photoUrl = widget.photoUrl;
      _photoPath = widget.photoPath;
    }
  }

  Future<void> _managePhoto() async {
    if (_isManaging) return;
    _isManaging = true;
    try {
      final action = await showModalBottomSheet<_ProfilePhotoAction>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: AppColors.themedSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.orange,
                  ),
                  title: const Text('Take photo'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfilePhotoAction.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.orange,
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfilePhotoAction.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color:
                        _photoUrl?.isNotEmpty == true ||
                            _photoPath?.isNotEmpty == true
                        ? AppColors.danger
                        : AppColors.themedGrey,
                  ),
                  title: const Text('Remove photo'),
                  enabled:
                      _photoUrl?.isNotEmpty == true ||
                      _photoPath?.isNotEmpty == true,
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfilePhotoAction.remove),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || action == null) return;

      setState(() => _isBusy = true);
      if (action == _ProfilePhotoAction.remove) {
        final shouldRemove = await _confirmRemoval();
        if (!mounted || !shouldRemove) return;
        await context.read<AuthProvider>().removeProfilePhoto();
        if (!mounted) return;
        setState(() {
          _photoUrl = null;
          _photoPath = null;
        });
        _showMessage('Profile photo removed.');
        return;
      }

      final image = await _imagePicker.pickImage(
        source: action == _ProfilePhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;

      await _processPickedImage(image);
    } on PlatformException catch (error) {
      _showPhotoError(error);
    } catch (error) {
      _showPhotoError(error);
    } finally {
      _isManaging = false;
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;

      final files = response.files;
      if (files != null && files.isNotEmpty) {
        _isManaging = true;
        setState(() => _isBusy = true);
        await _processPickedImage(files.first);
      } else if (response.exception != null) {
        throw response.exception!;
      }
    } on PlatformException catch (error) {
      _showPhotoError(error);
    } catch (error) {
      _showPhotoError(error);
    } finally {
      _isManaging = false;
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _processPickedImage(XFile image) async {
    final sourceLength = await image.length();
    if (sourceLength > ProfilePhotoValidation.maxSourceBytes) {
      throw const FormatException('Image must be smaller than 20 MB.');
    }
    final sourceHeader = await image.openRead(0, 12).fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) {
        builder.add(chunk);
        return builder;
      },
    );
    ProfilePhotoValidation.validateAndGetContentType(
      sourceHeader.takeBytes(),
      maxBytes: ProfilePhotoValidation.maxSourceBytes,
    );
    if (!mounted) return;

    final croppedImage = await ImageCropper().cropImage(
      sourcePath: image.path,
      maxWidth: 1024,
      maxHeight: 1024,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 82,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile photo',
          toolbarColor: AppColors.orange,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.orange,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop profile photo',
          doneButtonTitle: 'Use photo',
          cancelButtonTitle: 'Cancel',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
        if (kIsWeb)
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            viewwMode: WebViewMode.mode_1,
            dragMode: WebDragMode.move,
            minCropBoxWidth: 100,
            minCropBoxHeight: 100,
            themeData: const WebThemeData(rotateIconColor: AppColors.orange),
          ),
      ],
    );
    if (croppedImage == null || !mounted) return;

    final croppedBytes = await croppedImage.readAsBytes();
    ProfilePhotoValidation.validateAndGetContentType(
      croppedBytes,
      maxBytes: ProfilePhotoValidation.maxSourceBytes,
    );
    final imageBytes = await compute<Uint8List, Uint8List>(
      ProfilePhotoValidation.prepareForUpload,
      croppedBytes,
    );
    final contentType = ProfilePhotoValidation.validateAndGetContentType(
      imageBytes,
      maxBytes: ProfilePhotoValidation.maxUploadBytes,
    );
    if (contentType != 'image/jpeg') {
      throw const FormatException('The cropped photo must be a JPEG image.');
    }

    final confirmed = await _showPreview(imageBytes);
    if (!mounted || confirmed != true) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    final photoPath = await context.read<AuthProvider>().updateProfilePhoto(
      imageBytes,
      contentType: contentType,
      onProgress: (progress) {
        if (mounted) setState(() => _uploadProgress = progress);
      },
    );
    if (!mounted) return;
    setState(() {
      _photoUrl = null;
      _uploadProgress = 0;
      _photoPath = photoPath;
    });
    _showMessage('Profile photo updated.');
  }

  void _showPhotoError(Object error) {
    if (!mounted) return;
    if (error is PlatformException) {
      final message = switch (error.code) {
        'camera_access_denied' || 'camera_access_denied_without_prompt' =>
          'Camera access is denied. Enable it in your device settings.',
        'photo_access_denied' ||
        'photo_access_denied_without_prompt' ||
        'read_external_storage_denied' =>
          'Photo access is denied. Enable it in your device settings.',
        _ =>
          'Could not process the profile photo: ${error.message ?? error.code}',
      };
      _showMessage(message, isError: true);
      return;
    }
    if (error is FirebaseException) {
      final message = switch (error.code) {
        'permission-denied' || 'unauthorized' =>
          'You do not have permission to upload this profile photo.',
        'unauthenticated' =>
          'Your session has expired. Sign in again and retry.',
        'network-request-failed' || 'retry-limit-exceeded' =>
          'Network error while uploading. Check your connection and retry.',
        _ => error.message ?? error.code,
      };
      _showMessage('Could not update profile photo: $message', isError: true);
      return;
    }
    if (error is FormatException || error is StateError) {
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        isError: true,
      );
      return;
    }
    _showMessage('Could not update profile photo: $error', isError: true);
  }

  Future<bool> _confirmRemoval() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.themedSurface,
            title: const Text('Remove profile photo?'),
            content: const Text(
              'Your default profile icon will be shown instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool?> _showPreview(Uint8List imageBytes) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.themedSurface,
      title: const Text('Preview profile photo'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                imageBytes,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 200,
                  height: 200,
                  child: Icon(Icons.person, size: 100),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This cropped photo will appear in a circular profile frame.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Retake'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save photo'),
        ),
      ],
    ),
  );

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Semantics(
      button: true,
      label: 'Edit profile photo',
      child: InkWell(
        onTap: _isBusy ? null : _managePhoto,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfilePhoto(
              photoUrl: _photoUrl,
              photoPath: _photoPath,
              size: widget.compact ? 76 : 88,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.themedSurface, width: 2),
                ),
                child: Icon(
                  _isBusy ? Icons.hourglass_top : Icons.camera_alt,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final editButton = OutlinedButton.icon(
      onPressed: _isBusy ? null : _managePhoto,
      icon: _isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_a_photo_outlined),
      label: Text(
        _isBusy
            ? _isUploading
                  ? 'Uploading photo...'
                  : 'Preparing photo...'
            : widget.compact
            ? 'Edit photo'
            : 'Change photo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final uploadProgress = _isUploading
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_uploadProgress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    if (widget.compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.displayName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.displayEmail ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.themedGrey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                editButton,
                uploadProgress,
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        avatar,
        const SizedBox(height: 10),
        editButton,
        if (_isUploading) SizedBox(width: 140, child: uploadProgress),
      ],
    );
  }
}

enum _ProfilePhotoAction { camera, gallery, remove }

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.trailing,
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
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
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
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: AppColors.themedGrey,
                  size: 20,
                ),
          ],
        ),
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
  final VoidCallback? onEdit;

  const _BikeCard({
    required this.bike,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
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
                          BikeBrandLogo(brand: bike.brand),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Edit bike',
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.orange,
                          size: 20,
                        ),
                      ),
                  ],
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
                      '${bike.engineCapacity == bike.engineCapacity!.roundToDouble() ? bike.engineCapacity!.toStringAsFixed(0) : bike.engineCapacity} cc',
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
                    color: AppColors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.orange, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AppColors.orange,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: AppColors.orange,
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
    if (name.contains('red')) return AppColors.orange;
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
