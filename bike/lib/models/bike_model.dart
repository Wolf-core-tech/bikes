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

  String? get logoAssetPath {
    switch (this) {
      case BikeBrand.heroMotoCorp:
        return 'assets/brand/HEROMOTOCO.png';
      case BikeBrand.tvsMotorCompany:
        return 'assets/brand/TVS.png';
      case BikeBrand.yamahaMotorIndia:
        return 'assets/brand/YAMAHA.png';
      case BikeBrand.hondaMotorcycleScoterIndia:
        return 'assets/brand/honda.png';
      case BikeBrand.bajajauto:
        return 'assets/brand/BAJAJ.png';
      case BikeBrand.royalEnfield:
        return 'assets/brand/royal-enfield.png';
      case BikeBrand.suzukiMotorcycleIndia:
        return 'assets/brand/suzuki.png';
      case BikeBrand.ktm:
        return 'assets/brand/ktm.png';
      case BikeBrand.kawasaki:
        return 'assets/brand/kawasaki.png';
      case BikeBrand.bmwMotorrad:
        return 'assets/brand/BMW.png';
      case BikeBrand.ducati:
        return 'assets/brand/Ducati.png';
      case BikeBrand.triumphMotorcycles:
        return 'assets/brand/triumph.png';
      case BikeBrand.harleyDavidson:
        return 'assets/brand/Harley.png';
      case BikeBrand.indianMotorcycle:
        return 'assets/brand/Indian.png';
      case BikeBrand.jawa:
        return 'assets/brand/Jawa.png';
      case BikeBrand.yezdi:
        return 'assets/brand/Custom.png';
      case BikeBrand.benelli:
        return 'assets/brand/Benelli.png';
      case BikeBrand.husqvarna:
        return 'assets/brand/Husqvarna.png';
      case BikeBrand.aprilia:
        return 'assets/brand/Aprilia.png';
      case BikeBrand.atherEnergy:
        return 'assets/brand/ATHER.png';
      case BikeBrand.olaElectric:
        return 'assets/brand/Ola.png';
      case BikeBrand.simpleEnergy:
        return 'assets/brand/Custom.png';
      case BikeBrand.other:
        return 'assets/brand/Custom.png';
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
    case 'Ather Energy':
      return BikeBrand.atherEnergy;
    case 'Ola Electric':
      return BikeBrand.olaElectric;
    case 'Simple Energy':
      return BikeBrand.simpleEnergy;
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
  final String? vehicleType;

  Bike({
    required this.id,
    required this.name,
    required this.brand,
    this.model,
    this.yearOfPurchase,
    this.licensePlate,
    this.color,
    this.engineCapacity,
    this.vehicleType,
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
    String? vehicleType,
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
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
}
