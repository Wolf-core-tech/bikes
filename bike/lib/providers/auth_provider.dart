import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/profile_health_details.dart';
import '../services/notification_service.dart';
import '../utils/profile_photo_validation.dart';

/// AUTH FLOW:
/// ─────────────────────────────────────────────────────────────
/// • Firebase Auth auto-persists the user session on device.
///   After a cold restart, _auth.currentUser is non-null immediately.
/// • checkLoginStatus() reads _auth.currentUser as the primary source.
///   If that's null (local-only account), it falls back to SharedPreferences.
/// • The authStateChanges() listener is ONLY used to keep the local
///   profile cache fresh — it NEVER clears the user on null events.
/// • logout() is the only method that signs the user out.
/// ─────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  static const String _registeredUsersKey = 'registered_users_list';
  static const String _sessionUidKey = 'local_session_uid';

  bool _isInitialized = false;
  UserModel? _currentUser;
  ProfileHealthDetails _profileHealthDetails = const ProfileHealthDetails();
  List<UserModel> _registeredUsers = [];
  bool _profilePhotoOperationInProgress = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  UserModel? get currentUser => _currentUser;
  ProfileHealthDetails get profileHealthDetails => _profileHealthDetails;
  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  AuthProvider() {
    // Only used for background profile refresh, NOT for session management.
    try {
      _authSubscription = _auth.authStateChanges().listen((firebaseUser) {
        if (firebaseUser != null && _currentUser != null) {
          // Silently update the profile cache when Firebase comes online.
          _refreshProfileCache(firebaseUser);
        }
        // Intentionally DO NOT clear _currentUser when firebaseUser == null.
        // Firebase emits null briefly on cold start — we must ignore it.
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  // ─── CALLED ONCE AT STARTUP (from SplashScreen) ───────────────────────────

  Future<bool> checkLoginStatus() async {
    try {
      // ① Firebase Auth is the primary source — it persists automatically.
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _buildUserFromFirebase(firebaseUser);
        return true;
      }

      // ② Fallback: local-only accounts stored in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_sessionUidKey);
      if (savedUid != null && savedUid.isNotEmpty) {
        final rawUsers = prefs.getString(_registeredUsersKey);
        if (rawUsers != null) {
          final records = (json.decode(rawUsers) as List<dynamic>).map(
            (r) => UserModel.fromMap(Map<String, dynamic>.from(r)),
          );
          for (final user in records) {
            if (user.uid == savedUid) {
              _currentUser = user;
              _profileHealthDetails = const ProfileHealthDetails();
              _isInitialized = true;
              notifyListeners();
              return true;
            }
          }
        }
        // Stale session key — clean up
        await prefs.remove(_sessionUidKey);
      }

      _isInitialized = true;
      _currentUser = null;
      _profileHealthDetails = const ProfileHealthDetails();
      notifyListeners();
      return false;
    } catch (_) {
      _isInitialized = true;
      _currentUser = null;
      _profileHealthDetails = const ProfileHealthDetails();
      notifyListeners();
      return false;
    }
  }

  // ─── BUILD LOCAL PROFILE FROM FIREBASE USER ────────────────────────────────

  Future<void> _buildUserFromFirebase(User firebaseUser) async {
    _profileHealthDetails = const ProfileHealthDetails();
    UserModel profile;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final data = doc.data() ?? {};
      _profileHealthDetails = await _readProfileHealthDetails(firebaseUser.uid);
      profile = UserModel(
        uid: firebaseUser.uid,
        name: data['name'] as String? ?? firebaseUser.displayName ?? 'Rider',
        bio: data['bio'] as String? ?? '',
        email: firebaseUser.email ?? data['email'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        password: '',
        bikeStatus: data['bikeStatus'] as String? ?? "Don't have bike",
        photoUrl: data.containsKey('photoUrl')
            ? data['photoUrl'] as String?
            : firebaseUser.photoURL,
        photoPath: data['photoPath'] as String?,
        bikeBrand: data['bikeBrand'] as String?,
        bikeModel: data['bikeModel'] as String?,
        bikeCc: data['bikeCc'] as String?,
        bikeVehicleType: data['bikeVehicleType'] as String?,
        bikeYear: data['bikeYear'] as String?,
        bikeRegistration: data['bikeRegistration'] as String?,
      );

      if (!doc.exists) {
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          ...profile.toFirestoreMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _registeredUsers = await _loadFirestoreUsers();
    } catch (_) {
      // Firestore failed — restore from local cache
      profile =
          await _getCachedUser(firebaseUser.uid) ??
          UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'Rider',
            email: firebaseUser.email ?? '',
            phone: '',
            password: '',
            bikeStatus: "Don't have bike",
          );
    }
    _currentUser = profile;
    _isInitialized = true;
    await _saveCachedUser(profile);
    notifyListeners();
  }

  // ─── BACKGROUND PROFILE REFRESH (does NOT affect session state) ────────────

  Future<void> _refreshProfileCache(User firebaseUser) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final data = doc.data() ?? {};
      _profileHealthDetails = await _readProfileHealthDetails(firebaseUser.uid);
      final updated = UserModel(
        uid: firebaseUser.uid,
        name: data['name'] as String? ?? _currentUser?.name ?? 'Rider',
        bio: data['bio'] as String? ?? _currentUser?.bio ?? '',
        email: firebaseUser.email ?? _currentUser?.email ?? '',
        phone: data['phone'] as String? ?? _currentUser?.phone ?? '',
        password: _currentUser?.password ?? '',
        bikeStatus:
            data['bikeStatus'] as String? ??
            _currentUser?.bikeStatus ??
            "Don't have bike",
        bikeBrand: data['bikeBrand'] as String? ?? _currentUser?.bikeBrand,
        bikeModel: data['bikeModel'] as String? ?? _currentUser?.bikeModel,
        bikeCc: data['bikeCc'] as String? ?? _currentUser?.bikeCc,
        bikeVehicleType:
            data['bikeVehicleType'] as String? ?? _currentUser?.bikeVehicleType,
        bikeYear: data['bikeYear'] as String? ?? _currentUser?.bikeYear,
        bikeRegistration:
            data['bikeRegistration'] as String? ??
            _currentUser?.bikeRegistration,
        photoUrl: data.containsKey('photoUrl')
            ? data['photoUrl'] as String?
            : firebaseUser.photoURL ?? _currentUser?.photoUrl,
        photoPath: data.containsKey('photoPath')
            ? data['photoPath'] as String?
            : _currentUser?.photoPath,
      );
      _currentUser = updated;
      await _saveCachedUser(updated);
      notifyListeners();
    } catch (_) {
      // Firestore unavailable — keep existing user, no-op
    }
  }

  // ─── REGISTER ──────────────────────────────────────────────────────────────

  Future<void> registerUser(UserModel newUser) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: newUser.email.trim(),
        password: newUser.password,
      );
      final firebaseUser = credential.user!;
      await firebaseUser.updateDisplayName(newUser.name);

      // Send Email Verification
      if (!firebaseUser.emailVerified) {
        await firebaseUser.sendEmailVerification();
      }

      final profile = UserModel(
        uid: firebaseUser.uid,
        name: newUser.name,
        email: newUser.email.trim(),
        phone: newUser.phone,
        password: newUser.password,
        bikeStatus: newUser.bikeStatus,
        bikeBrand: newUser.bikeBrand,
        bikeModel: newUser.bikeModel,
        bikeCc: newUser.bikeCc,
        bikeVehicleType: newUser.bikeVehicleType,
        bikeYear: newUser.bikeYear,
        bikeRegistration: newUser.bikeRegistration,
      );

      // Store in Firestore WITHOUT the password (security)
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        ...profile.toFirestoreMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store in local cache (with password for local auth fallback)
      await _saveCachedUser(profile);

      // DO NOT sign out — Firebase persists this session automatically
      // The register screen navigates to Login, login will sign them in properly
    } catch (_) {
      // Firebase unavailable — register locally only
      final profile = UserModel(
        uid: 'local_${DateTime.now().millisecondsSinceEpoch}',
        name: newUser.name,
        email: newUser.email.trim(),
        phone: newUser.phone,
        password: newUser.password,
        bikeStatus: newUser.bikeStatus,
        bikeBrand: newUser.bikeBrand,
        bikeModel: newUser.bikeModel,
        bikeCc: newUser.bikeCc,
        bikeVehicleType: newUser.bikeVehicleType,
        bikeYear: newUser.bikeYear,
        bikeRegistration: newUser.bikeRegistration,
      );
      await _saveCachedUser(profile);
    }
  }

  // ─── LOGIN ─────────────────────────────────────────────────────────────────

  Future<String?> loginUser(String email, String password) async {
    // ① Try Firebase Authentication
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Check if email is verified
      if (credential.user != null && !credential.user!.emailVerified) {
        await _auth.signOut();
        return 'unverified_email';
      }

      // Firebase now holds the session — it will persist across restarts
      await _buildUserFromFirebase(credential.user!);
      await NotificationService().updateToken();
      return null;
    } on FirebaseAuthException catch (e) {
      // ② Firebase failed — try local-only account as fallback
      final localError = await _tryLocalLogin(email, password);
      if (localError == null) return null;

      return switch (e.code) {
        'user-not-found' => 'No account found. Please register first.',
        'wrong-password' ||
        'invalid-credential' => 'Incorrect email or password.',
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Unable to sign in right now.',
      };
    } catch (_) {
      final localError = await _tryLocalLogin(email, password);
      if (localError == null) return null;
      return 'Unable to sign in. Please try again.';
    }
  }

  Future<String?> _tryLocalLogin(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUsers = prefs.getString(_registeredUsersKey);
      if (rawUsers == null) return 'No local account found.';
      final records = (json.decode(rawUsers) as List<dynamic>).map(
        (r) => UserModel.fromMap(Map<String, dynamic>.from(r)),
      );
      for (final user in records) {
        if (user.email.trim().toLowerCase() == email.trim().toLowerCase() &&
            user.password == password) {
          _currentUser = user;
          _profileHealthDetails = const ProfileHealthDetails();
          _isInitialized = true;
          // Save session key for local accounts
          await prefs.setString(_sessionUidKey, user.uid ?? '');
          notifyListeners();
          return null;
        }
      }
      return 'Incorrect email or password.';
    } catch (_) {
      return 'Unable to sign in. Please try again.';
    }
  }

  // ─── RESEND VERIFICATION EMAIL ─────────────────────────────────────────────

  Future<String?> resendVerificationEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null && !credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
        await _auth.signOut();
        return null; // Successfully sent
      }
      if (credential.user != null && credential.user!.emailVerified) {
        await _auth.signOut();
        return 'Email is already verified.';
      }
      return 'User not found.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Unable to resend verification email.';
    } catch (_) {
      return 'Unable to resend verification email. Please try again.';
    }
  }

  // ─── UPDATE PROFILE ────────────────────────────────────────────────────────

  Future<void> updateCurrentUser(UserModel updatedUser) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in to update your profile.');
    }
    final profile = UserModel(
      uid: firebaseUser.uid,
      name: updatedUser.name,
      bio: updatedUser.bio,
      email: firebaseUser.email ?? updatedUser.email,
      phone: updatedUser.phone,
      password: _currentUser?.password ?? '',
      bikeStatus: updatedUser.bikeStatus,
      bikeBrand: updatedUser.bikeBrand,
      bikeModel: updatedUser.bikeModel,
      bikeCc: updatedUser.bikeCc,
      bikeVehicleType: updatedUser.bikeVehicleType,
      bikeYear: updatedUser.bikeYear,
      bikeRegistration: updatedUser.bikeRegistration,
      photoUrl: _currentUser == null
          ? updatedUser.photoUrl
          : _currentUser!.photoUrl,
      photoPath: _currentUser == null
          ? updatedUser.photoPath
          : _currentUser!.photoPath,
    );
    await firebaseUser.updateDisplayName(profile.name);
    try {
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(profile.toFirestoreMap());
    } catch (_) {}
    _currentUser = profile;
    await _saveCachedUser(profile);
    notifyListeners();
  }

  Future<ProfileHealthDetails> loadVisibleProfileHealthDetails(
    String userId,
  ) async {
    final fields = _firestore
        .collection('profileDetails')
        .doc(userId)
        .collection('fields');

    Future<Map<String, dynamic>?> readField(String field) async {
      try {
        final snapshot = await fields.doc(field).get();
        return snapshot.data();
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') return null;
        rethrow;
      }
    }

    final fieldData = await Future.wait([
      readField('dateOfBirth'),
      readField('bloodGroup'),
      readField('healthIssue'),
    ]);
    final dateOfBirthData = fieldData[0];
    final bloodGroupData = fieldData[1];
    final healthIssueData = fieldData[2];

    return ProfileHealthDetails(
      dateOfBirth: _nonEmptyString(dateOfBirthData?['value']),
      bloodGroup: _nonEmptyString(bloodGroupData?['value']),
      healthIssue: _nonEmptyString(healthIssueData?['value']),
      dateOfBirthVisibility: ProfileFieldVisibility.fromValue(
        dateOfBirthData?['visibility'],
      ),
      healthIssueVisibility: ProfileFieldVisibility.fromValue(
        healthIssueData?['visibility'],
      ),
    );
  }

  Future<void> updateProfileHealthDetails(ProfileHealthDetails details) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in to update your health details.');
    }
    if ((details.dateOfBirth?.length ?? 0) > 10 ||
        (details.healthIssue?.length ?? 0) > 500 ||
        (details.bloodGroup?.length ?? 0) > 5) {
      throw const FormatException('One or more health details are too long.');
    }
    const bloodGroups = {
      '',
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
    };
    if (!bloodGroups.contains(details.bloodGroup ?? '')) {
      throw const FormatException('Choose a valid blood group.');
    }

    final fields = _firestore
        .collection('profileDetails')
        .doc(firebaseUser.uid)
        .collection('fields');
    final batch = _firestore.batch()
      ..set(fields.doc('dateOfBirth'), {
        'value': details.dateOfBirth ?? '',
        'visibility': details.dateOfBirthVisibility.value,
      })
      ..set(fields.doc('bloodGroup'), {'value': details.bloodGroup ?? ''})
      ..set(fields.doc('healthIssue'), {
        'value': details.healthIssue ?? '',
        'visibility': details.healthIssueVisibility.value,
      });
    await batch.commit();
    _profileHealthDetails = details;
    notifyListeners();
  }

  Future<ProfileHealthDetails> _readProfileHealthDetails(String userId) async {
    final fields = _firestore
        .collection('profileDetails')
        .doc(userId)
        .collection('fields');
    final snapshots = await Future.wait([
      fields.doc('dateOfBirth').get(),
      fields.doc('bloodGroup').get(),
      fields.doc('healthIssue').get(),
    ]);
    final dateOfBirthData = snapshots[0].data();
    final bloodGroupData = snapshots[1].data();
    final healthIssueData = snapshots[2].data();
    return ProfileHealthDetails(
      dateOfBirth: _nonEmptyString(dateOfBirthData?['value']),
      bloodGroup: _nonEmptyString(bloodGroupData?['value']),
      healthIssue: _nonEmptyString(healthIssueData?['value']),
      dateOfBirthVisibility: ProfileFieldVisibility.fromValue(
        dateOfBirthData?['visibility'],
      ),
      healthIssueVisibility: ProfileFieldVisibility.fromValue(
        healthIssueData?['visibility'],
      ),
    );
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<String> updateProfilePhoto(
    Uint8List imageBytes, {
    String contentType = 'image/jpeg',
    ValueChanged<double>? onProgress,
  }) async {
    final firebaseUser = _auth.currentUser;
    final currentProfile = _currentUser;
    if (firebaseUser == null || currentProfile == null) {
      throw StateError('Sign in to upload a profile photo.');
    }
    if (_profilePhotoOperationInProgress) {
      throw StateError('A profile photo operation is already in progress.');
    }
    final detectedType = ProfilePhotoValidation.validateAndGetContentType(
      imageBytes,
      maxBytes: ProfilePhotoValidation.maxUploadBytes,
    );
    if (detectedType != contentType || contentType != 'image/jpeg') {
      throw const FormatException(
        'Profile photos must be cropped to JPEG before uploading.',
      );
    }

    _profilePhotoOperationInProgress = true;
    final storage = FirebaseStorage.instance;
    final oldPhotoPath = _photoStoragePath(currentProfile, firebaseUser.uid);
    final newPhotoPath =
        'profile_photos/${firebaseUser.uid}/${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.jpg';
    final newPhotoRef = storage.ref().child(newPhotoPath);

    try {
      final uploadTask = newPhotoRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'private,max-age=3600',
        ),
      );
      final progressSubscription = uploadTask.snapshotEvents.listen(
        (snapshot) {
          final totalBytes = snapshot.totalBytes;
          if (totalBytes > 0) {
            onProgress?.call(
              (snapshot.bytesTransferred / totalBytes)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            );
          }
        },
        onError: (Object error) {
          debugPrint('Profile photo upload progress stream failed: $error');
        },
      );
      try {
        await uploadTask;
      } finally {
        await progressSubscription.cancel();
      }

      final downloadUrl = await newPhotoRef.getDownloadURL();
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'photoUrl': downloadUrl,
        'photoPath': newPhotoPath,
      }, SetOptions(merge: true));

      final updatedProfile = currentProfile.copyWith(
        photoUrl: downloadUrl,
        photoPath: newPhotoPath,
      );
      _currentUser = updatedProfile;
      notifyListeners();
      try {
        await _saveCachedUser(updatedProfile);
      } catch (error) {
        debugPrint('Unable to cache the updated profile photo: $error');
      }
      await _deletePreviousPhoto(oldPhotoPath, firebaseUser.uid);
      return newPhotoPath;
    } catch (_) {
      await _deletePhotoFile(newPhotoPath, firebaseUser.uid);
      rethrow;
    } finally {
      _profilePhotoOperationInProgress = false;
    }
  }

  Future<void> removeProfilePhoto() async {
    final firebaseUser = _auth.currentUser;
    final currentProfile = _currentUser;
    if (firebaseUser == null || currentProfile == null) {
      throw StateError('Sign in to remove your profile photo.');
    }
    if (_profilePhotoOperationInProgress) {
      throw StateError('A profile photo operation is already in progress.');
    }

    _profilePhotoOperationInProgress = true;
    final oldPhotoPath = _photoStoragePath(currentProfile, firebaseUser.uid);
    var authPhotoUpdated = false;
    try {
      await firebaseUser.updatePhotoURL(null);
      authPhotoUpdated = true;
      try {
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'photoUrl': null,
          'photoPath': null,
        }, SetOptions(merge: true));
      } catch (_) {
        await _restoreAuthPhoto(firebaseUser, currentProfile.photoUrl);
        authPhotoUpdated = false;
        rethrow;
      }

      final updatedProfile = currentProfile.copyWith(
        clearPhoto: true,
        clearPhotoPath: true,
      );
      _currentUser = updatedProfile;
      notifyListeners();
      try {
        await _saveCachedUser(updatedProfile);
      } catch (error) {
        debugPrint('Unable to cache the removed profile photo: $error');
      }
      await _deletePreviousPhoto(oldPhotoPath, firebaseUser.uid);
    } catch (_) {
      if (authPhotoUpdated) {
        await _restoreAuthPhoto(firebaseUser, currentProfile.photoUrl);
      }
      rethrow;
    } finally {
      _profilePhotoOperationInProgress = false;
    }
  }

  Future<void> deleteAccount({String? password}) async {
    final firebaseUser = _auth.currentUser;
    final currentProfile = _currentUser;
    if (currentProfile == null) {
      throw StateError('There is no signed-in account to delete.');
    }

    if (firebaseUser != null) {
      final usesPassword = firebaseUser.providerData.any(
        (provider) => provider.providerId == 'password',
      );
      if (usesPassword) {
        if (password == null || password.isEmpty) {
          throw StateError('Enter your password to confirm account deletion.');
        }
        final email = firebaseUser.email;
        if (email == null || email.isEmpty) {
          throw StateError('This account cannot be reauthenticated by email.');
        }
        await firebaseUser.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      }

      final photoPath = _photoStoragePath(currentProfile, firebaseUser.uid);
      if (photoPath != null) {
        await _deletePhotoFile(photoPath, firebaseUser.uid);
      }
      final detailFields = _firestore
          .collection('profileDetails')
          .doc(firebaseUser.uid)
          .collection('fields');
      final detailBatch = _firestore.batch()
        ..delete(detailFields.doc('dateOfBirth'))
        ..delete(detailFields.doc('bloodGroup'))
        ..delete(detailFields.doc('healthIssue'));
      await detailBatch.commit();
      await _firestore.collection('users').doc(firebaseUser.uid).delete();
      await _firestore
          .collection('publicProfiles')
          .doc(firebaseUser.uid)
          .delete();
      await firebaseUser.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    final remainingUsers = _registeredUsers
        .where((user) => user.uid != currentProfile.uid)
        .toList();
    _registeredUsers = remainingUsers;
    await prefs.setString(
      _registeredUsersKey,
      json.encode(remainingUsers.map((user) => user.toMap()).toList()),
    );
    await prefs.remove(_sessionUidKey);
    _currentUser = null;
    _profileHealthDetails = const ProfileHealthDetails();
    notifyListeners();
  }

  String? _photoStoragePath(UserModel profile, String userId) {
    if (profile.photoPath != null) return profile.photoPath;
    if (profile.photoUrl?.contains('profile_photos%2F$userId%2Fprofile') ==
        true) {
      return 'profile_photos/$userId/profile';
    }
    return null;
  }

  Future<void> _restoreAuthPhoto(User firebaseUser, String? photoUrl) async {
    try {
      await firebaseUser.updatePhotoURL(photoUrl);
    } catch (error) {
      debugPrint('Unable to restore the previous auth profile photo: $error');
    }
  }

  Future<void> _deletePreviousPhoto(String? path, String userId) async {
    if (path == null) return;
    await _deletePhotoFile(path, userId);
  }

  Future<void> _deletePhotoFile(String path, String userId) async {
    final prefix = 'profile_photos/$userId/';
    if (!path.startsWith(prefix)) {
      debugPrint('Skipped deleting an invalid profile photo path: $path');
      return;
    }
    try {
      await FirebaseStorage.instance.ref().child(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        debugPrint('Unable to delete old profile photo $path: $error');
      }
    } catch (error) {
      debugPrint('Unable to delete old profile photo $path: $error');
    }
  }

  // ─── LOGOUT — the ONLY way the user is signed out ─────────────────────────

  Future<void> logout() async {
    try {
      setPresence(false); // Do not await to prevent blocking if offline
      await NotificationService().removeToken();
      await _auth.signOut();
    } catch (_) {}
    // Clear local-account session key (Firebase session cleared automatically)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUidKey);
    _currentUser = null;
    _profileHealthDetails = const ProfileHealthDetails();
    notifyListeners();
  }

  // ─── PRESENCE ──────────────────────────────────────────────────────────────

  Future<void> setPresence(bool isOnline) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      await _firestore.collection('users').doc(userId).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Future<UserModel?> _getCachedUser(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUsers = prefs.getString(_registeredUsersKey);
      if (rawUsers == null) return null;
      final records = (json.decode(rawUsers) as List<dynamic>).map(
        (r) => UserModel.fromMap(Map<String, dynamic>.from(r)),
      );
      for (final user in records) {
        if (user.uid == uid) return user;
      }
    } catch (_) {}
    return null;
  }

  Future<List<UserModel>> _loadFirestoreUsers() async {
    try {
      final snapshot = await _firestore.collection('publicProfiles').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel.fromMap({
          'uid': doc.id,
          'name': data['name'] as String? ?? 'Rider',
          'photoPath': data['photoPath'] as String?,
          'photoUrl': data['photoUrl'] as String?,
          'email': '',
          'phone': '',
          'password': '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final cached =
        _registeredUsers.where((item) => item.uid != user.uid).toList()
          ..add(user);
    _registeredUsers = cached;
    await prefs.setString(
      _registeredUsersKey,
      json.encode(cached.map((item) => item.toMap()).toList()),
    );
  }
}
