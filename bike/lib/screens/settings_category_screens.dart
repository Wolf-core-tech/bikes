import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import 'notification_settings_screen.dart';

class PreferencesSettingsScreen extends StatelessWidget {
  const PreferencesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return _SettingsPage(
      title: 'App preferences',
      subtitle: 'Make Bike Squad feel right for you.',
      icon: Icons.tune_rounded,
      children: [
        _SettingsPanel(
          title: 'Appearance',
          children: [
            _SettingsSwitch(
              icon: theme.isDarkMode
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              title: 'Dark theme',
              subtitle: 'Use a darker look throughout the app',
              value: theme.isDarkMode,
              onChanged: theme.setTheme,
            ),
            const _SettingsDivider(),
            _SettingsValue(
              icon: Icons.text_fields_rounded,
              title: 'Text size',
              subtitle: 'Adjust text throughout the app',
              child: DropdownButton<double>(
                value: theme.fontScale,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0.9, child: Text('Small')),
                  DropdownMenuItem(value: 1, child: Text('Default')),
                  DropdownMenuItem(value: 1.15, child: Text('Large')),
                ],
                onChanged: (value) {
                  if (value != null) theme.setFontScale(value);
                },
              ),
            ),
            const _SettingsDivider(),
            _SettingsAction(
              icon: Icons.language_rounded,
              title: 'Language',
              subtitle: 'English',
              onTap: () => _showInfo(
                context,
                'Language',
                'English is currently the only available language.',
              ),
            ),
            const _SettingsDivider(),
            _SettingsAction(
              icon: Icons.palette_outlined,
              title: 'Accent color',
              subtitle: 'Bike Squad red',
              onTap: () => _showInfo(
                context,
                'Accent color',
                'Bike Squad uses its signature red accent throughout the app.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsPanel(
          title: 'Sounds & alerts',
          children: [
            _SettingsAction(
              icon: Icons.notifications_none_rounded,
              title: 'Notification settings',
              subtitle: 'Sound, vibration and push alerts',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  bool _clearing = false;
  String _cacheUsage = 'Checking cache...';

  @override
  void initState() {
    super.initState();
    _loadCacheUsage();
  }

  Future<void> _loadCacheUsage() async {
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final cacheDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}osm_tile_cache',
      );
      var bytes = 0;
      if (await cacheDirectory.exists()) {
        await for (final entity in cacheDirectory.list(recursive: true)) {
          if (entity is File) bytes += await entity.length();
        }
      }
      if (mounted) setState(() => _cacheUsage = _formatBytes(bytes));
    } catch (error) {
      if (mounted) setState(() => _cacheUsage = 'Unavailable');
      debugPrint('Unable to calculate cached map storage: $error');
    }
  }

  Future<void> _clearCache() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final cacheDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}osm_tile_cache',
      );
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
      await cacheDirectory.create(recursive: true);
      if (!mounted) return;
      setState(() => _cacheUsage = '0 B');
      _showMessage('Cached map tiles were cleared.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not clear the cache: $error', isError: true);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _openPermissions() async {
    try {
      final opened = await Geolocator.openAppSettings();
      if (!mounted) return;
      if (!opened) {
        _showMessage('Could not open device settings.', isError: true);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not open device settings: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Storage & permissions',
    subtitle: 'Manage cached data and device access.',
    icon: Icons.storage_outlined,
    children: [
      _SettingsPanel(
        title: 'Storage',
        children: [
          _SettingsAction(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear temporary cache',
            subtitle: 'Remove temporary files and cached map tiles',
            trailing: _clearing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _clearing ? null : _clearCache,
          ),
          const _SettingsDivider(),
          _SettingsAction(
            icon: Icons.donut_small_outlined,
            title: 'Storage used',
            subtitle: 'Cached map tiles: $_cacheUsage',
            onTap: _loadCacheUsage,
          ),
          const _SettingsDivider(),
          const _SettingsAction(
            icon: Icons.download_outlined,
            title: 'Downloads',
            subtitle: 'No saved downloads',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsPanel(
        title: 'Device access',
        children: [
          _SettingsAction(
            icon: Icons.phonelink_setup_rounded,
            title: 'App permissions',
            subtitle: 'Review location and notification permissions',
            onTap: _openPermissions,
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _SettingsPanel(
        title: 'Network & data',
        children: [
          _SettingsAction(
            icon: Icons.map_outlined,
            title: 'Offline maps',
            subtitle: 'Previously viewed map tiles are cached automatically',
          ),
          _SettingsDivider(),
          _SettingsAction(
            icon: Icons.data_usage_outlined,
            title: 'Data usage',
            subtitle: 'Maps, messages and ride updates use network data',
          ),
          _SettingsDivider(),
          _SettingsAction(
            icon: Icons.system_update_alt_rounded,
            title: 'App updates',
            subtitle: 'Updates are managed by your app store',
          ),
        ],
      ),
    ],
  );
}

class SupportSettingsScreen extends StatelessWidget {
  const SupportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Support & about',
    subtitle: 'Find help and learn more about Bike Squad.',
    icon: Icons.help_outline_rounded,
    children: [
      _SettingsPanel(
        title: 'Help',
        children: [
          _SettingsAction(
            icon: Icons.support_agent_rounded,
            title: 'Help & support',
            subtitle: 'Get assistance with the app',
            onTap: () => _showInfo(
              context,
              'Help & support',
              'For help, use the feedback option in your app store or contact the Bike Squad app administrator.',
            ),
          ),
          const _SettingsDivider(),
          _SettingsAction(
            icon: Icons.quiz_outlined,
            title: 'Frequently asked questions',
            subtitle: 'Common questions about Bike Squad',
            onTap: () => _showInfo(
              context,
              'Frequently asked questions',
              'You can manage your squad, bikes, rides and notifications from the app. For account access issues, contact the Bike Squad app administrator.',
            ),
          ),
          const _SettingsDivider(),
          _SettingsAction(
            icon: Icons.rate_review_outlined,
            title: 'Send feedback',
            subtitle: 'Share an idea or report a problem',
            onTap: () => _showInfo(
              context,
              'Send feedback',
              'Feedback options depend on the app store or organization where you installed Bike Squad.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsPanel(
        title: 'Legal',
        children: [
          _SettingsAction(
            icon: Icons.description_outlined,
            title: 'Terms & conditions',
            subtitle: 'Review the terms for using the app',
            onTap: () => _showInfo(
              context,
              'Terms & conditions',
              'Terms are not configured for this app yet.',
            ),
          ),
          const _SettingsDivider(),
          _SettingsAction(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            subtitle: 'Learn how your information is handled',
            onTap: () => _showInfo(
              context,
              'Privacy policy',
              'A privacy policy has not been configured for this app yet.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _SettingsPanel(
        title: 'About',
        children: [
          _SettingsAction(
            icon: Icons.motorcycle_outlined,
            title: 'Bike Squad',
            subtitle: 'Version 1.0.0',
            trailing: SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.themedBackground,
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.themedCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.orange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(color: AppColors.themedGrey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.themedCard,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.themedGrey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.orange, size: 21),
    title: Text(
      title,
      style: TextStyle(
        color: AppColors.themedText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
    ),
    trailing:
        trailing ??
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.themedGrey,
          size: 20,
        ),
  );
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.orange, size: 21),
    title: Text(
      title,
      style: TextStyle(
        color: AppColors.themedText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
    ),
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.orange,
    ),
  );
}

class _SettingsValue extends StatelessWidget {
  const _SettingsValue({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.orange, size: 21),
    title: Text(
      title,
      style: TextStyle(
        color: AppColors.themedText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
    ),
    trailing: child,
  );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 54,
    endIndent: 16,
    color: AppColors.themedGreyBorder.withValues(alpha: 0.35),
  );
}

void _showInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.themedSurface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
