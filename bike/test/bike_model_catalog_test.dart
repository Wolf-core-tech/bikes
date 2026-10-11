import 'package:bikers/models/bike_model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Hero catalog includes verified motorcycle and scooter specifications',
    () {
      final heroModels = BikeModelCatalog.forBrand('Hero MotoCorp');

      expect(heroModels, isNotEmpty);
      expect(
        BikeModelCatalog.find('Hero MotoCorp', 'Splendor Plus')?.engineCC,
        97.2,
      );
      expect(
        BikeModelCatalog.find('Hero MotoCorp', 'XPulse 200 4V')?.engineCC,
        199.6,
      );
      expect(
        BikeModelCatalog.find('Hero MotoCorp', 'Destini 110')?.vehicleType,
        'Scooter',
      );
      expect(
        BikeModelCatalog.find('Hero MotoCorp', 'VIDA V2 Lite')?.engineCCLabel,
        'Not available',
      );
      expect(
        BikeModelCatalog.find('Hero MotoCorp', 'Passion Pro')?.engineCCLabel,
        'Not available',
      );
    },
  );

  test('brand filtering excludes other manufacturers', () {
    final heroModels = BikeModelCatalog.forBrand('Hero MotoCorp');
    final yamahaModels = BikeModelCatalog.forBrand('Yamaha');
    final bajajModels = BikeModelCatalog.forBrand('Bajaj');
    final suzukiModels = BikeModelCatalog.forBrand('Suzuki');
    final bmwModels = BikeModelCatalog.forBrand('BMW Motorrad');
    final ktmModels = BikeModelCatalog.forBrand('KTM');
    final royalEnfieldModels = BikeModelCatalog.forBrand('Royal Enfield');
    final triumphModels = BikeModelCatalog.forBrand('Triumph Motorcycles');
    final tvsModels = BikeModelCatalog.forBrand('TVS');
    final ducatiModels = BikeModelCatalog.forBrand('Ducati');
    final harleyDavidsonModels = BikeModelCatalog.forBrand('Harley-Davidson');
    final indianMotorcycleModels = BikeModelCatalog.forBrand(
      'Indian Motorcycle',
    );
    final apriliaModels = BikeModelCatalog.forBrand('Aprilia');
    final benelliModels = BikeModelCatalog.forBrand('Benelli');
    final jawaModels = BikeModelCatalog.forBrand('Jawa');
    final yezdiModels = BikeModelCatalog.forBrand('Yezdi');
    final husqvarnaModels = BikeModelCatalog.forBrand('Husqvarna');
    final atherModels = BikeModelCatalog.forBrand('Ather Energy');
    final olaModels = BikeModelCatalog.forBrand('Ola Electric');

    expect(heroModels.every((model) => model.brand == 'Hero MotoCorp'), isTrue);
    expect(yamahaModels, isNotEmpty);
    expect(yamahaModels.every((model) => model.brand == 'Yamaha'), isTrue);
    expect(bajajModels, isNotEmpty);
    expect(bajajModels.every((model) => model.brand == 'Bajaj'), isTrue);
    expect(suzukiModels, isNotEmpty);
    expect(suzukiModels.every((model) => model.brand == 'Suzuki'), isTrue);
    expect(bmwModels, isNotEmpty);
    expect(bmwModels.every((model) => model.brand == 'BMW Motorrad'), isTrue);
    expect(ktmModels, isNotEmpty);
    expect(ktmModels.every((model) => model.brand == 'KTM'), isTrue);
    expect(royalEnfieldModels, isNotEmpty);
    expect(
      royalEnfieldModels.every((model) => model.brand == 'Royal Enfield'),
      isTrue,
    );
    expect(triumphModels, isNotEmpty);
    expect(
      triumphModels.every((model) => model.brand == 'Triumph Motorcycles'),
      isTrue,
    );
    expect(tvsModels, isNotEmpty);
    expect(tvsModels.every((model) => model.brand == 'TVS'), isTrue);
    expect(ducatiModels, isNotEmpty);
    expect(ducatiModels.every((model) => model.brand == 'Ducati'), isTrue);
    expect(harleyDavidsonModels, isNotEmpty);
    expect(
      harleyDavidsonModels.every((model) => model.brand == 'Harley-Davidson'),
      isTrue,
    );
    expect(indianMotorcycleModels, isNotEmpty);
    expect(
      indianMotorcycleModels.every(
        (model) => model.brand == 'Indian Motorcycle',
      ),
      isTrue,
    );
    expect(apriliaModels, isNotEmpty);
    expect(apriliaModels.every((model) => model.brand == 'Aprilia'), isTrue);
    expect(benelliModels, isNotEmpty);
    expect(benelliModels.every((model) => model.brand == 'Benelli'), isTrue);
    expect(jawaModels, isNotEmpty);
    expect(jawaModels.every((model) => model.brand == 'Jawa'), isTrue);
    expect(yezdiModels, isNotEmpty);
    expect(yezdiModels.every((model) => model.brand == 'Yezdi'), isTrue);
    expect(husqvarnaModels, isNotEmpty);
    expect(
      husqvarnaModels.every((model) => model.brand == 'Husqvarna'),
      isTrue,
    );
    expect(atherModels, isNotEmpty);
    expect(atherModels.every((model) => model.brand == 'Ather Energy'), isTrue);
    expect(olaModels, isNotEmpty);
    expect(olaModels.every((model) => model.brand == 'Ola Electric'), isTrue);
    expect(BikeModelCatalog.forBrand('Honda'), isNotEmpty);
  });

  test(
    'Bajaj catalog includes verified models and electric Chetak CC status',
    () {
      final bajajModels = BikeModelCatalog.forBrand('Bajaj');

      expect(BikeModelCatalog.find('Bajaj', 'Pulsar N160')?.engineCC, 164.82);
      expect(BikeModelCatalog.find('Bajaj', 'Dominar 400')?.engineCC, 349.13);
      expect(BikeModelCatalog.find('Bajaj', 'Chetak')?.vehicleType, 'Scooter');
      expect(
        BikeModelCatalog.find('Bajaj', 'Chetak')?.engineCCLabel,
        'Not available',
      );
      expect(
        BikeModelCatalog.find(
          'Bajaj',
          'Boxer / Boxer CT / BM series',
        )?.engineCCLabel,
        'Not available',
      );
      expect(bajajModels.length, 43);
    },
  );

  test(
    'Suzuki catalog includes verified models and electric e-Access CC status',
    () {
      final suzukiModels = BikeModelCatalog.forBrand('Suzuki');

      expect(BikeModelCatalog.find('Suzuki', 'Gixxer')?.engineCC, 155);
      expect(BikeModelCatalog.find('Suzuki', 'Hayabusa')?.engineCC, 1340);
      expect(
        BikeModelCatalog.find('Suzuki', 'Burgman Street')?.vehicleType,
        'Scooter',
      );
      expect(
        BikeModelCatalog.find('Suzuki', 'e-Access')?.engineCCLabel,
        'Not available',
      );
      expect(
        BikeModelCatalog.find(
          'Suzuki',
          'GSX-R / GSX-S / V-Strom larger international families',
        )?.engineCCLabel,
        'Not available',
      );
      expect(suzukiModels.length, 28);
    },
  );

  test(
    'Honda catalog includes verified models and electric scooter CC status',
    () {
      final hondaModels = BikeModelCatalog.forBrand('Honda');

      expect(BikeModelCatalog.find('Honda', 'Shine 100')?.engineCC, 98.98);
      expect(BikeModelCatalog.find('Honda', 'CB350')?.engineCC, 348.36);
      expect(
        BikeModelCatalog.find('Honda', 'Activa 125')?.vehicleType,
        'Scooter',
      );
      expect(
        BikeModelCatalog.find('Honda', 'Activa e:')?.engineCCLabel,
        'Not available',
      );
      expect(
        BikeModelCatalog.find(
          'Honda',
          'Activa (older generations)',
        )?.engineCCLabel,
        'Not available',
      );
      expect(hondaModels.length, 66);
    },
  );

  test(
    'BMW Motorrad catalog includes verified models and electric CC status',
    () {
      final bmwModels = BikeModelCatalog.forBrand('BMW Motorrad');

      expect(BikeModelCatalog.find('BMW Motorrad', 'G 310 R')?.engineCC, 313);
      expect(
        BikeModelCatalog.find('BMW Motorrad', 'G 310 RR')?.engineCC,
        312.12,
      );
      expect(
        BikeModelCatalog.find('BMW Motorrad', 'R 1300 GS')?.engineCC,
        1300,
      );
      expect(
        BikeModelCatalog.find('BMW Motorrad', 'C 400 GT')?.vehicleType,
        'Scooter',
      );
      expect(
        BikeModelCatalog.find('BMW Motorrad', 'CE 04')?.engineCCLabel,
        'Not available',
      );
      expect(bmwModels.length, 40);
    },
  );

  test('KTM catalog includes verified Duke and Adventure specifications', () {
    final ktmModels = BikeModelCatalog.forBrand('KTM');

    expect(BikeModelCatalog.find('KTM', '160 Duke')?.engineCC, 164.2);
    expect(BikeModelCatalog.find('KTM', '390 Duke')?.engineCC, 398.63);
    expect(
      BikeModelCatalog.find('KTM', '390 Adventure (350 variant)')?.engineCC,
      349.32,
    );
    expect(
      BikeModelCatalog.find('KTM', 'RC GP')?.engineCCLabel,
      'Not available',
    );
    expect(ktmModels.length, 27);
  });

  test(
    'Royal Enfield catalog includes verified models and electric CC status',
    () {
      final models = BikeModelCatalog.forBrand('Royal Enfield');

      expect(
        BikeModelCatalog.find(
          'Royal Enfield',
          'Classic 350 (reborn)',
        )?.engineCC,
        349,
      );
      expect(
        BikeModelCatalog.find('Royal Enfield', 'Himalayan 450')?.engineCC,
        452,
      );
      expect(
        BikeModelCatalog.find(
          'Royal Enfield',
          'Bullet Machismo',
        )?.engineCCLabel,
        'Not available',
      );
      expect(
        BikeModelCatalog.find('Royal Enfield', 'Flying Flea C6')?.engineCCLabel,
        'Not available',
      );
      expect(models.length, 49);
    },
  );

  test(
    'Triumph catalog includes verified models and flags variant-dependent CC',
    () {
      final models = BikeModelCatalog.forBrand('Triumph Motorcycles');

      expect(
        BikeModelCatalog.find(
          'Triumph Motorcycles',
          'Bonneville T100',
        )?.engineCC,
        900,
      );
      expect(
        BikeModelCatalog.find(
          'Triumph Motorcycles',
          'Rocket 3 Storm R',
        )?.engineCC,
        2458,
      );
      expect(
        BikeModelCatalog.find('Triumph Motorcycles', 'TF 450-X')?.engineCC,
        450,
      );
      expect(
        BikeModelCatalog.find(
          'Triumph Motorcycles',
          'Speed 400',
        )?.engineCCLabel,
        'Not available',
      );
      expect(models.length, 41);
    },
  );

  test('TVS catalog includes bikes, scooters, and electric models', () {
    final models = BikeModelCatalog.forBrand('TVS');

    expect(BikeModelCatalog.find('TVS', 'Apache RTX')?.engineCC, 299.1);
    expect(BikeModelCatalog.find('TVS', 'Apache RTR 200 4V')?.engineCC, 197.75);
    expect(
      BikeModelCatalog.find('TVS', 'Apache RTR 200 4V')?.variant,
      contains('confirm exact model year and variant'),
    );
    expect(
      BikeModelCatalog.find('TVS', 'TVS Jupiter 125')?.vehicleType,
      'Scooter',
    );
    expect(
      BikeModelCatalog.find('TVS', 'TVS iQube')?.engineCCLabel,
      'Not available',
    );
    expect(BikeModelCatalog.find('TVS', 'TVS iQube')?.fuelType, 'Electric');
    expect(BikeModelCatalog.find('TVS', 'TVS XL100')?.engineCC, 99.7);
    expect(models.length, 22);
  });

  test('Ducati catalog includes model specifications and generation notes', () {
    final models = BikeModelCatalog.forBrand('Ducati');

    expect(BikeModelCatalog.find('Ducati', 'Diavel V4')?.engineCC, 1158);
    expect(
      BikeModelCatalog.find('Ducati', 'Hypermotard 698 Mono')?.engineCC,
      659,
    );
    expect(BikeModelCatalog.find('Ducati', 'Panigale V4 R')?.engineCC, 998);
    expect(BikeModelCatalog.find('Ducati', 'Desmo450 MX')?.engineCC, 449.6);
    expect(
      BikeModelCatalog.find('Ducati', 'Monster')?.variant,
      contains('older versions are 937 cc'),
    );
    expect(models.length, 31);
  });

  test(
    'Harley-Davidson catalog includes current and selected recent models',
    () {
      final models = BikeModelCatalog.forBrand('Harley-Davidson');

      expect(BikeModelCatalog.find('Harley-Davidson', 'X440')?.engineCC, 440);
      expect(
        BikeModelCatalog.find('Harley-Davidson', 'Street Bob')?.engineCC,
        1923,
      );
      expect(
        BikeModelCatalog.find('Harley-Davidson', 'Nightster')?.engineCC,
        975,
      );
      expect(
        BikeModelCatalog.find('Harley-Davidson', 'Iron 883')?.variant,
        contains('Discontinued'),
      );
      expect(
        BikeModelCatalog.find('Harley-Davidson', 'CVO Road Glide')?.variant,
        contains('verify exact model year and market'),
      );
      expect(models.length, 28);
    },
  );

  test(
    'Indian Motorcycle catalog includes current and older engine families',
    () {
      final models = BikeModelCatalog.forBrand('Indian Motorcycle');

      expect(
        BikeModelCatalog.find('Indian Motorcycle', 'Scout Classic')?.engineCC,
        1250,
      );
      expect(
        BikeModelCatalog.find(
          'Indian Motorcycle',
          'Chieftain PowerPlus',
        )?.engineCC,
        1834,
      );
      expect(
        BikeModelCatalog.find(
          'Indian Motorcycle',
          'Older Scout / Scout Bobber',
        )?.engineCC,
        1133,
      );
      expect(
        BikeModelCatalog.find(
          'Indian Motorcycle',
          'Older Challenger / Pursuit',
        )?.variant,
        contains('PowerPlus 108'),
      );
      expect(models.length, 32);
    },
  );

  test('Aprilia catalog includes motorcycles and scooters', () {
    final models = BikeModelCatalog.forBrand('Aprilia');

    expect(BikeModelCatalog.find('Aprilia', 'RS 457')?.engineCC, 457);
    expect(
      BikeModelCatalog.find('Aprilia', 'RSV4 / RSV4 Factory')?.engineCC,
      1099,
    );
    expect(
      BikeModelCatalog.find(
        'Aprilia',
        'SR 160 / SR Carbon 160 / SR Race 160',
      )?.vehicleType,
      'Scooter',
    );
    expect(BikeModelCatalog.find('Aprilia', 'SR GT 400')?.engineCC, 399);
    expect(models.length, 21);
  });

  test('Benelli catalog includes India, international, and older models', () {
    final models = BikeModelCatalog.forBrand('Benelli');

    expect(BikeModelCatalog.find('Benelli', 'Leoncino 500')?.engineCC, 500);
    expect(BikeModelCatalog.find('Benelli', 'TRK 702X')?.engineCC, 698);
    expect(
      BikeModelCatalog.find('Benelli', 'TNT 600i / BN 600i')?.variant,
      contains('Older'),
    );
    expect(BikeModelCatalog.find('Benelli', 'TNT 135')?.engineCC, 134.7);
    expect(models.length, 25);
  });

  test('Jawa catalog includes the current India motorcycle range', () {
    final models = BikeModelCatalog.forBrand('Jawa');

    expect(BikeModelCatalog.find('Jawa', 'Jawa 42')?.engineCC, 294.72);
    expect(BikeModelCatalog.find('Jawa', 'Jawa 42 FJ')?.engineCC, 334);
    expect(BikeModelCatalog.find('Jawa', 'Jawa 42 Bobber')?.engineCC, 334);
    expect(BikeModelCatalog.find('Jawa', 'Jawa 350')?.vehicleType, 'Bike');
    expect(BikeModelCatalog.find('Jawa', 'Jawa Perak')?.engineCC, 334);
    expect(models.length, 5);
  });

  test('Yezdi catalog includes Adventure, Roadster, and Scrambler', () {
    final models = BikeModelCatalog.forBrand('Yezdi');

    expect(BikeModelCatalog.find('Yezdi', 'Yezdi Adventure')?.engineCC, 334);
    expect(BikeModelCatalog.find('Yezdi', 'Yezdi Roadster')?.engineCC, 334);
    expect(BikeModelCatalog.find('Yezdi', 'Yezdi Scrambler')?.engineCC, 334);
    expect(models.length, 3);
  });

  test('Husqvarna catalog includes generation-specific and legacy models', () {
    final models = BikeModelCatalog.forBrand('Husqvarna');

    expect(
      BikeModelCatalog.find(
        'Husqvarna',
        'Vitpilen 401 (older generation)',
      )?.engineCC,
      373,
    );
    expect(
      BikeModelCatalog.find(
        'Husqvarna',
        'Vitpilen 401 (newer generation)',
      )?.engineCC,
      399,
    );
    expect(
      BikeModelCatalog.find('Husqvarna', 'Svartpilen 200')?.engineCC,
      199.5,
    );
    expect(BikeModelCatalog.find('Husqvarna', 'Nuda 900 R')?.engineCC, 898);
    expect(BikeModelCatalog.find('Husqvarna', '701 Enduro')?.engineCC, 692.7);
    expect(models.length, 19);
  });

  test('Ather catalog records electric models without combustion CC', () {
    final models = BikeModelCatalog.forBrand('Ather Energy');

    expect(models.length, 6);
    expect(
      models.every(
        (model) =>
            model.vehicleType == 'Scooter' &&
            model.fuelType == 'Electric' &&
            model.engineCC == null,
      ),
      isTrue,
    );
    expect(
      BikeModelCatalog.find('Ather Energy', 'Ather 450S')?.electricMotorPowerKW,
      5.4,
    );
    expect(
      BikeModelCatalog.find('Ather Energy', 'Ather 450X')?.electricMotorPowerKW,
      6.4,
    );
    expect(
      BikeModelCatalog.find(
        'Ather Energy',
        'Ather 450 Apex',
      )?.electricMotorPowerKW,
      7.0,
    );
    expect(
      BikeModelCatalog.find('Ather Energy', 'Ather Konarc')?.variant,
      contains('Check official specifications'),
    );
  });

  test(
    'Ola catalog records Roadster battery capacities separately from CC',
    () {
      final models = BikeModelCatalog.forBrand('Ola Electric');

      expect(models.length, 4);
      expect(
        models.every(
          (model) =>
              model.vehicleType == 'Bike' &&
              model.fuelType == 'Electric' &&
              model.engineCC == null,
        ),
        isTrue,
      );
      expect(
        BikeModelCatalog.find(
          'Ola Electric',
          'Ola Roadster X',
        )?.batteryCapacitiesKWh,
        [2.5, 3.5, 4.5],
      );
      expect(
        BikeModelCatalog.find(
          'Ola Electric',
          'Ola Roadster X+',
        )?.batteryCapacitiesKWh,
        [4.5, 9.1],
      );
      expect(
        BikeModelCatalog.find('Ola Electric', 'Ola Roadster')?.variant,
        contains('varies by version'),
      );
      expect(
        BikeModelCatalog.find('Ola Electric', 'Ola Roadster Pro')?.variant,
        contains('varies by version'),
      );
    },
  );
}
