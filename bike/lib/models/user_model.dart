import 'dart:convert';

class UserModel {
  final String? uid;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String? photoUrl;
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
    this.photoUrl,
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
      'photoUrl': photoUrl,
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
      'photoUrl': photoUrl,
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
      photoUrl: map['photoUrl'] as String?,
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

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? password,
    String? bikeStatus,
    String? bikeBrand,
    String? bikeModel,
    String? bikeCc,
    String? bikeYear,
    String? bikeRegistration,
    String? photoUrl,
  }) => UserModel(
    uid: uid,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    password: password ?? this.password,
    bikeStatus: bikeStatus ?? this.bikeStatus,
    bikeBrand: bikeBrand ?? this.bikeBrand,
    bikeModel: bikeModel ?? this.bikeModel,
    bikeCc: bikeCc ?? this.bikeCc,
    bikeYear: bikeYear ?? this.bikeYear,
    bikeRegistration: bikeRegistration ?? this.bikeRegistration,
    photoUrl: photoUrl ?? this.photoUrl,
  );
}
