import 'package:flutter/foundation.dart';
import '../models/bike_model.dart';

class BikeProvider extends ChangeNotifier {
  List<Bike> _bikes = [];
  Bike? _activeBike;

  List<Bike> get bikes => _bikes;
  Bike? get activeBike => _activeBike;

  BikeProvider() {
    _initDemo();
  }

  void _initDemo() {
    _bikes = [
      Bike(
        id: 'bike_001',
        name: 'My Hero Honda',
        brand: BikeBrand.heroMotoCorp,
        model: 'Hero Splendor Plus',
        yearOfPurchase: 2022,
        licensePlate: 'TN-01-XX-0001',
        color: 'Black',
        engineCapacity: 97.2,
      ),
      Bike(
        id: 'bike_002',
        name: 'Royal Beast',
        brand: BikeBrand.royalEnfield,
        model: 'Royal Enfield Classic 350',
        yearOfPurchase: 2021,
        licensePlate: 'TN-01-XX-0002',
        color: 'Chrome',
        engineCapacity: 346.0,
      ),
    ];
    _activeBike = _bikes.isNotEmpty ? _bikes.first : null;
  }

  void addBike(Bike bike) {
    _bikes.add(bike);
    notifyListeners();
  }

  void updateBike(String bikeId, Bike updatedBike) {
    final index = _bikes.indexWhere((b) => b.id == bikeId);
    if (index != -1) {
      _bikes[index] = updatedBike;
      if (_activeBike?.id == bikeId) {
        _activeBike = updatedBike;
      }
      notifyListeners();
    }
  }

  void removeBike(String bikeId) {
    _bikes.removeWhere((b) => b.id == bikeId);
    if (_activeBike?.id == bikeId) {
      _activeBike = _bikes.isNotEmpty ? _bikes.first : null;
    }
    notifyListeners();
  }

  void setActiveBike(Bike bike) {
    _activeBike = bike;
    notifyListeners();
  }

  Bike? getBikeById(String bikeId) {
    try {
      return _bikes.firstWhere((b) => b.id == bikeId);
    } catch (_) {
      return null;
    }
  }

  List<Bike> getBikesByBrand(BikeBrand brand) {
    return _bikes.where((b) => b.brand == brand).toList();
  }
}
