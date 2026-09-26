enum BikeBrand {
  heroMotoCorp,
  hondaMotorcycleScoterIndia,
  tvsMotorCompany,
  bajajauto,
  royalEnfield,
  yamahaMotorIndia,
  suzukiMotorcycleIndia,
  ktm,
  kawasaki,
  bmwMotorrad,
  ducati,
  triumphMotorcycles,
  harleyDavidson,
  indianMotorcycle,
  jawa,
  yezdi,
  benelli,
  husqvarna,
  aprilia,
  atherEnergy,
  olaElectric,
  simpleEnergy,
  other,
}

extension BikeBrandExtension on BikeBrand {
  String get displayName {
    switch (this) {
      case BikeBrand.heroMotoCorp:
        return 'Hero MotoCorp';
      case BikeBrand.hondaMotorcycleScoterIndia:
        return 'Honda Motorcycle & Scooter India';
      case BikeBrand.tvsMotorCompany:
        return 'TVS Motor Company';
      case BikeBrand.bajajauto:
        return 'Bajaj Auto';
      case BikeBrand.royalEnfield:
        return 'Royal Enfield';
      case BikeBrand.yamahaMotorIndia:
        return 'Yamaha Motor India';
      case BikeBrand.suzukiMotorcycleIndia:
        return 'Suzuki Motorcycle India';
      case BikeBrand.ktm:
        return 'KTM';
      case BikeBrand.kawasaki:
        return 'Kawasaki';
      case BikeBrand.bmwMotorrad:
        return 'BMW Motorrad';
      case BikeBrand.ducati:
        return 'Ducati';
      case BikeBrand.triumphMotorcycles:
        return 'Triumph Motorcycles';
      case BikeBrand.harleyDavidson:
        return 'Harley-Davidson';
      case BikeBrand.indianMotorcycle:
        return 'Indian Motorcycle';
      case BikeBrand.jawa:
        return 'Jawa';
      case BikeBrand.yezdi:
        return 'Yezdi';
      case BikeBrand.benelli:
        return 'Benelli';
      case BikeBrand.husqvarna:
        return 'Husqvarna';
      case BikeBrand.aprilia:
        return 'Aprilia';
      case BikeBrand.atherEnergy:
        return 'Ather Energy';
      case BikeBrand.olaElectric:
        return 'Ola Electric';
      case BikeBrand.simpleEnergy:
        return 'Simple Energy';
      case BikeBrand.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case BikeBrand.heroMotoCorp:
        return '🔴';
      case BikeBrand.hondaMotorcycleScoterIndia:
        return '🔵';
      case BikeBrand.tvsMotorCompany:
        return '🟠';
      case BikeBrand.bajajauto:
        return '🟡';
      case BikeBrand.royalEnfield:
        return '🟤';
      case BikeBrand.yamahaMotorIndia:
        return '🔘';
      case BikeBrand.suzukiMotorcycleIndia:
        return '🟣';
      case BikeBrand.ktm:
        return '🟠';
      case BikeBrand.kawasaki:
        return '🟢';
      case BikeBrand.bmwMotorrad:
        return '⚪';
      case BikeBrand.ducati:
        return '🔴';
      case BikeBrand.triumphMotorcycles:
        return '🟦';
      case BikeBrand.harleyDavidson:
        return '🟥';
      case BikeBrand.indianMotorcycle:
        return '🟤';
      case BikeBrand.jawa:
        return '🟨';
      case BikeBrand.yezdi:
        return '🟩';
      case BikeBrand.benelli:
        return '🟠';
      case BikeBrand.husqvarna:
        return '🟢';
      case BikeBrand.aprilia:
        return '🟪';
      case BikeBrand.atherEnergy:
        return '⚡';
      case BikeBrand.olaElectric:
        return '🔌';
      case BikeBrand.simpleEnergy:
        return '💡';
      case BikeBrand.other:
        return '🏍️';
    }
  }
}

BikeBrand bikeBrandFromRegistrationName(String brand) {
  switch (brand) {
    case 'Hero MotoCorp':
      return BikeBrand.heroMotoCorp;
    case 'Honda':
      return BikeBrand.hondaMotorcycleScoterIndia;
    case 'TVS':
      return BikeBrand.tvsMotorCompany;
    case 'Bajaj':
      return BikeBrand.bajajauto;
    case 'Royal Enfield':
      return BikeBrand.royalEnfield;
    case 'Yamaha':
      return BikeBrand.yamahaMotorIndia;
    case 'Suzuki':
      return BikeBrand.suzukiMotorcycleIndia;
    case 'KTM':
      return BikeBrand.ktm;
    case 'Kawasaki':
      return BikeBrand.kawasaki;
    case 'BMW Motorrad':
      return BikeBrand.bmwMotorrad;
    case 'Triumph':
      return BikeBrand.triumphMotorcycles;
    case 'Ducati':
      return BikeBrand.ducati;
    case 'Harley-Davidson':
      return BikeBrand.harleyDavidson;
    case 'Indian Motorcycle':
      return BikeBrand.indianMotorcycle;
    case 'Aprilia':
      return BikeBrand.aprilia;
    case 'Benelli':
      return BikeBrand.benelli;
    case 'Jawa':
      return BikeBrand.jawa;
    case 'Yezdi':
      return BikeBrand.yezdi;
    case 'Husqvarna':
      return BikeBrand.husqvarna;
    case 'Other':
      return BikeBrand.other;
    default:
      throw ArgumentError.value(brand, 'brand', 'Unknown bike brand');
  }
}

class Bike {
  final String id;
  final String name;
  final BikeBrand brand;
  final String? model;
  final int? yearOfPurchase;
  final String? licensePlate;
  final String? color;
  final double? engineCapacity; // in CC

  Bike({
    required this.id,
    required this.name,
    required this.brand,
    this.model,
    this.yearOfPurchase,
    this.licensePlate,
    this.color,
    this.engineCapacity,
  });

  Bike copyWith({
    String? id,
    String? name,
    BikeBrand? brand,
    String? model,
    int? yearOfPurchase,
    String? licensePlate,
    String? color,
    double? engineCapacity,
  }) {
    return Bike(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      yearOfPurchase: yearOfPurchase ?? this.yearOfPurchase,
      licensePlate: licensePlate ?? this.licensePlate,
      color: color ?? this.color,
      engineCapacity: engineCapacity ?? this.engineCapacity,
    );
  }
}
