import 'package:flutter/material.dart';
import '../../models/rider_model.dart';
import '../../theme/app_theme.dart';

/// Avatar circle with initials and optional role badge
class RiderAvatar extends StatelessWidget {
  final Rider rider;
  final double size;
  final bool showBadge;

  const RiderAvatar({
    super.key,
    required this.rider,
    this.size = 48,
    this.showBadge = true,
  });

  Color _roleColor(RiderRole role) {
    switch (role) {
      case RiderRole.leader:
        return AppColors.orange;
      case RiderRole.coLeader:
        return const Color(0xFFAA88FF);
      case RiderRole.guard:
        return const Color(0xFF00C8FF);
      case RiderRole.midRider:
        return const Color(0xFF30D158);
      case RiderRole.tail:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.themedGreyBorder,
            border: Border.all(
              color: _roleColor(rider.role),
              width: rider.isCurrentUser ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _roleColor(rider.role).withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              rider.avatarInitials,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: size * 0.33,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(rider.role),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.themedBackground,
                  width: 1.5,
                ),
              ),
              child: Text(
                rider.role.positionTag,
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Card with orange border, matching the app design
class OrangeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const OrangeCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? AppColors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: (borderColor ?? AppColors.white).withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Role chip with color coding
class RoleChip extends StatelessWidget {
  final RiderRole role;
  final bool compact;

  const RoleChip({super.key, required this.role, this.compact = false});

  Color get _color {
    switch (role) {
      case RiderRole.leader:
        return AppColors.orange;
      case RiderRole.coLeader:
        return const Color(0xFFAA88FF);
      case RiderRole.guard:
        return const Color(0xFF00C8FF);
      case RiderRole.midRider:
        return const Color(0xFF30D158);
      case RiderRole.tail:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(role.emoji, style: TextStyle(fontSize: compact ? 10 : 13)),
          const SizedBox(width: 4),
          Text(
            role.displayName.toUpperCase(),
            style: TextStyle(
              color: _color,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formation position indicator
class FormationSlot extends StatelessWidget {
  final Rider rider;
  final int position;

  const FormationSlot({super.key, required this.rider, required this.position});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#$position',
          style: TextStyle(
            color: AppColors.themedGrey,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        RiderAvatar(rider: rider, size: 52),
        const SizedBox(height: 6),
        Text(
          rider.name.split(' ').first,
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
