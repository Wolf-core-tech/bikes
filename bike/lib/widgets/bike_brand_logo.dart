import 'package:flutter/material.dart';

import '../models/bike_model.dart';
import '../theme/app_theme.dart';

class BikeBrandLogo extends StatelessWidget {
  const BikeBrandLogo({required this.brand, super.key, this.size = 40});

  final BikeBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = brand.logoAssetPath;
    if (assetPath == null) {
      return _placeholderLogo();
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _placeholderLogo(),
      ),
    );
  }

  Widget _placeholderLogo() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Icon(
        Icons.two_wheeler,
        color: AppColors.orange,
        size: size * 0.65,
      ),
    );
  }
}
