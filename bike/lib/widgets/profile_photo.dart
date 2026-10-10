import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.photoUrl,
    this.size = 100,
  });

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return Semantics(
      label: url?.isNotEmpty == true ? 'Profile photo' : 'Default profile photo',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.03),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.orange,
        ),
        child: ClipOval(
          child: url?.isNotEmpty == true
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final innerSize = size * 0.94;
    return SizedBox(
      width: innerSize,
      height: innerSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = constraints.biggest.shortestSide;
          return ClipOval(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFDCE6EF), Color(0xFFB7C8D8)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: extent * 0.08,
                  child: Container(
                    width: extent * 0.5,
                    height: extent * 0.55,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B2B26),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: extent * 0.2,
                  child: Container(
                    width: extent * 0.36,
                    height: extent * 0.43,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9B99A),
                      borderRadius: BorderRadius.all(
                        Radius.circular(extent * 0.2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: extent * 0.16,
                  child: Container(
                    width: extent * 0.4,
                    height: extent * 0.18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B2B26),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(extent * 0.2),
                        bottom: Radius.circular(extent * 0.08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -extent * 0.2,
                  child: Container(
                    width: extent * 0.84,
                    height: extent * 0.58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF394B5D),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(extent * 0.42),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
