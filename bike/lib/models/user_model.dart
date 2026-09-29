import 'dart:convert';

class UserModel {
  final String? uid;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String bikeStatus;
  final String? bikeBrand;
  final String? bikeModel;
  final String? bikeCc;
  final String? bikeYear;
  final String? bikeRegistration;

  UserModel({
    this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.bikeStatus,
    this.bikeBrand,
    this.bikeModel,
    this.bikeCc,
    this.bikeYear,
    this.bikeRegistration,
  });

  /// Used for Firestore — password is NEVER stored in the cloud
  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'bikeStatus': bikeStatus,
      'bikeBrand': bikeBrand,
      'bikeModel': bikeModel,
      'bikeCc': bikeCc,
      'bikeYear': bikeYear,
      'bikeRegistration': bikeRegistration,
    };
  }

  /// Used for local SharedPreferences cache (includes password for local auth)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'bikeStatus': bikeStatus,
      'bikeBrand': bikeBrand,
      'bikeModel': bikeModel,
      'bikeCc': bikeCc,
      'bikeYear': bikeYear,
      'bikeRegistration': bikeRegistration,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      bikeStatus: map['bikeStatus'] ?? 'Don\'t have bike',
      bikeBrand: map['bikeBrand'],
      bikeModel: map['bikeModel'],
      bikeCc: map['bikeCc'],
      bikeYear: map['bikeYear'],
      bikeRegistration: map['bikeRegistration'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));
}
