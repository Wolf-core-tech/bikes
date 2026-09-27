import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  static const String _registeredUsersKey = 'registered_users_list';

  bool _isInitialized = false;
  UserModel? _currentUser;
  List<UserModel> _registeredUsers = [];
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  bool get isLoggedIn {
    try {
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  bool get isInitialized => _isInitialized;
  UserModel? get currentUser => _currentUser;
  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  AuthProvider() {
    try {
      _authSubscription = _auth.authStateChanges().listen((user) {
        _loadAuthenticatedUser(user);
      });
    } catch (_) {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  Future<bool> checkLoginStatus() async {
    try {
      await _loadAuthenticatedUser(_auth.currentUser);
      return isLoggedIn;
    } catch (_) {
      _isInitialized = true;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> registerUser(UserModel newUser) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: newUser.email.trim(),
      password: newUser.password,
    );
    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(newUser.name);
    final profile = UserModel(
      uid: firebaseUser.uid,
      name: newUser.name,
      email: newUser.email.trim(),
      phone: newUser.phone,
      password: '',
      bikeStatus: newUser.bikeStatus,
      bikeBrand: newUser.bikeBrand,
      bikeModel: newUser.bikeModel,
      bikeCc: newUser.bikeCc,
      bikeYear: newUser.bikeYear,
      bikeRegistration: newUser.bikeRegistration,
    );
    await _firestore.collection('users').doc(firebaseUser.uid).set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _saveCachedUser(profile);
    await _auth.signOut();
  }

  Future<String?> loginUser(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _loadAuthenticatedUser(credential.user);
      return null;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' &&
          await _migrateLocalAccount(email, password)) {
        return null;
      }
      return switch (error.code) {
        'user-not-found' => 'No account found. Please register first.',
        'wrong-password' ||
        'invalid-credential' => 'Incorrect email or password.',
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => error.message ?? 'Unable to sign in right now.',
      };
    }
  }

  Future<bool> _migrateLocalAccount(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString(_registeredUsersKey);
    if (rawUsers == null) return false;
    final records = (json.decode(rawUsers) as List<dynamic>).map(
      (record) => UserModel.fromMap(Map<String, dynamic>.from(record)),
    );
    UserModel? legacyUser;
    for (final user in records) {
      if (user.email.trim().toLowerCase() == email.trim().toLowerCase() &&
          user.password == password) {
        legacyUser = user;
        break;
      }
    }
    if (legacyUser == null) return false;

    final credential = await _auth.createUserWithEmailAndPassword(
      email: legacyUser.email.trim(),
      password: password,
    );
    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(legacyUser.name);
    final profile = UserModel(
      uid: firebaseUser.uid,
      name: legacyUser.name,
      email: legacyUser.email,
      phone: legacyUser.phone,
      password: '',
      bikeStatus: legacyUser.bikeStatus,
      bikeBrand: legacyUser.bikeBrand,
      bikeModel: legacyUser.bikeModel,
      bikeCc: legacyUser.bikeCc,
      bikeYear: legacyUser.bikeYear,
      bikeRegistration: legacyUser.bikeRegistration,
    );
    await _firestore.collection('users').doc(firebaseUser.uid).set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _saveCachedUser(profile);
    await _loadAuthenticatedUser(firebaseUser);
    return true;
  }

  Future<void> loginDirect(UserModel user) async {
    await registerUser(user);
    await _auth.signInWithEmailAndPassword(
      email: user.email.trim(),
      password: user.password,
    );
  }

  Future<void> updateCurrentUser(UserModel updatedUser) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to update your profile.');
    final profile = UserModel(
      uid: user.uid,
      name: updatedUser.name,
      email: user.email ?? updatedUser.email,
      phone: updatedUser.phone,
      password: '',
      bikeStatus: updatedUser.bikeStatus,
      bikeBrand: updatedUser.bikeBrand,
      bikeModel: updatedUser.bikeModel,
      bikeCc: updatedUser.bikeCc,
      bikeYear: updatedUser.bikeYear,
      bikeRegistration: updatedUser.bikeRegistration,
    );
    await user.updateDisplayName(profile.name);
    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    _currentUser = profile;
    await _saveCachedUser(profile);
    notifyListeners();
  }

  Future<void> logout() async {
    await setPresence(false);
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

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

  Future<void> _loadAuthenticatedUser(User? user) async {
    if (user == null) {
      _currentUser = null;
      _isInitialized = true;
      notifyListeners();
      return;
    }
    final document = await _firestore.collection('users').doc(user.uid).get();
    final data = document.data() ?? {};
    _currentUser = UserModel(
      uid: user.uid,
      name: data['name'] as String? ?? user.displayName ?? 'Rider',
      email: user.email ?? data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      password: '',
      bikeStatus: data['bikeStatus'] as String? ?? 'Don\'t have bike',
      bikeBrand: data['bikeBrand'] as String?,
      bikeModel: data['bikeModel'] as String?,
      bikeCc: data['bikeCc'] as String?,
      bikeYear: data['bikeYear'] as String?,
      bikeRegistration: data['bikeRegistration'] as String?,
    );
    await _saveCachedUser(_currentUser!);
    _registeredUsers = await _loadUsers();
    _isInitialized = true;
    notifyListeners();
  }

  Future<List<UserModel>> _loadUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return UserModel.fromMap({...data, 'uid': document.id, 'password': ''});
    }).toList();
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
