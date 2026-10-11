import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfilePhoto extends StatefulWidget {
  const ProfilePhoto({
    super.key,
    required this.photoUrl,
    this.photoPath,
    this.size = 100,
  });

  final String? photoUrl;
  final String? photoPath;
  final double size;

  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  Future<Uint8List?>? _photoBytes;

  @override
  void initState() {
    super.initState();
    _loadPath(widget.photoPath);
  }

  @override
  void didUpdateWidget(covariant ProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) {
      _loadPath(widget.photoPath);
    }
  }

  void _loadPath(String? path) {
    final normalizedPath = path?.trim();
    _photoBytes = normalizedPath == null || normalizedPath.isEmpty
        ? null
        : FirebaseStorage.instance
              .ref()
              .child(normalizedPath)
              .getData(5 * 1024 * 1024);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl?.trim();
    final path = widget.photoPath?.trim();
    return Semantics(
      label: url?.isNotEmpty == true || path?.isNotEmpty == true
          ? 'Profile photo'
          : 'Default profile photo',
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: EdgeInsets.all(widget.size * 0.03),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.orange,
        ),
        child: ClipOval(
          child: path?.isNotEmpty == true
              ? FutureBuilder<Uint8List?>(
                  future: _photoBytes,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint(
                        'Unable to load profile photo from Storage: ${snapshot.error}',
                      );
                      return _placeholder(context);
                    }
                    final bytes = snapshot.data;
                    return bytes == null
                        ? _placeholder(context)
                        : Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth:
                                (widget.size *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            errorBuilder: (context, _, _) =>
                                _placeholder(context),
                          );
                  },
                )
              : url?.isNotEmpty == true
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (widget.size * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorBuilder: (context, _, _) => _placeholder(context),
                )
              : _placeholder(context),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: AppColors.themedSurface,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: widget.size * 0.58,
          color: AppColors.themedGrey,
        ),
      ),
    );
  }
}
