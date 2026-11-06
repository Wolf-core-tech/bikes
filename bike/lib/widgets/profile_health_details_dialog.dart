import 'package:flutter/material.dart';

import '../models/profile_health_details.dart';
import '../theme/app_theme.dart';

class ProfileHealthDetailsDialog extends StatelessWidget {
  const ProfileHealthDetailsDialog({
    super.key,
    required this.name,
    required this.details,
  });

  final String name;
  final ProfileHealthDetails details;

  @override
  Widget build(BuildContext context) {
    final visibleDetails = <(String, String)>[
      if (details.dateOfBirth != null)
        ('Date of birth', _formatDate(details.dateOfBirth!)),
      if (details.bloodGroup != null) ('Blood group', details.bloodGroup!),
      if (details.healthIssue != null) ('Health issue', details.healthIssue!),
    ];

    return AlertDialog(
      backgroundColor: AppColors.themedSurface,
      title: Text(name),
      content: SingleChildScrollView(
        child: visibleDetails.isEmpty
            ? Text(
                'No health details are shared with you.',
                style: TextStyle(color: AppColors.themedGrey),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in visibleDetails) ...[
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (label != visibleDetails.last.$1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
