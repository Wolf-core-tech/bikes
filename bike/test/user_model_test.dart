import 'package:flutter_test/flutter_test.dart';
import 'package:bikers/models/user_model.dart';

void main() {
  test('profile photo URL survives local and Firestore serialization', () {
    final user = UserModel(
      uid: 'rider-1',
      name: 'Rider',
      email: 'rider@example.com',
      phone: '+911234567890',
      password: 'Rider123',
      bikeStatus: 'Have bike',
      bikeBrand: 'Hero MotoCorp',
      bikeModel: 'Splendor Plus',
      bikeCc: '97.2',
      bikeVehicleType: 'Bike',
      photoUrl: 'https://example.com/profile.jpg',
      photoPath: 'profile_photos/rider-1/1_2.jpg',
    );

    expect(UserModel.fromJson(user.toJson()).photoUrl, user.photoUrl);
    expect(UserModel.fromJson(user.toJson()).photoPath, user.photoPath);
    expect(UserModel.fromMap(user.toFirestoreMap()).photoUrl, user.photoUrl);
    expect(UserModel.fromMap(user.toFirestoreMap()).photoPath, user.photoPath);
    expect(
      UserModel.fromJson(user.toJson()).bikeVehicleType,
      user.bikeVehicleType,
    );
    expect(
      UserModel.fromMap(user.toFirestoreMap()).bikeVehicleType,
      user.bikeVehicleType,
    );
    expect(user.copyWith(name: 'New Rider').photoUrl, user.photoUrl);
    expect(user.copyWith(clearPhoto: true).photoUrl, isNull);
    expect(user.copyWith(clearPhotoPath: true).photoPath, isNull);
  });

  test('older cached profile records default to no photo', () {
    final user = UserModel.fromMap({
      'uid': 'rider-1',
      'name': 'Rider',
      'email': 'rider@example.com',
      'phone': '',
      'password': '',
      'bikeStatus': 'Have bike',
    });

    expect(user.photoUrl, isNull);
  });
}
