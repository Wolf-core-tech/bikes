import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _customNotificationsEnabled = true;
  double _soundVolume = 0.7;
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    unawaited(_previewPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
        _soundEnabled = data['notificationSoundEnabled'] as bool? ?? true;
        _vibrationEnabled =
            data['notificationVibrationEnabled'] as bool? ?? true;
        _customNotificationsEnabled =
            data['customNotificationsEnabled'] as bool? ?? true;
        _soundVolume =
            (data['notificationSoundVolume'] as num?)?.toDouble() ?? 0.7;
        _loading = false;
      });
      await NotificationService().setPreferences(
        notificationsEnabled: _notificationsEnabled,
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        customNotificationsEnabled: _customNotificationsEnabled,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load notification settings: $error'),
          ),
        );
      }
    }
  }

  Future<void> _updatePreference(String field, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) return;
    final previous = _preferenceValue(field);
    setState(() {
      _saving = true;
      _setPreferenceValue(field, value);
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {field: value},
      );
      await NotificationService().setPreferences(
        notificationsEnabled: _notificationsEnabled,
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        customNotificationsEnabled: _customNotificationsEnabled,
      );
      if (field == 'notificationVibrationEnabled' && value) {
        await NotificationService().previewVibration();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _setPreferenceValue(field, previous));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save notification setting: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateSoundVolume(double value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) return;
    final previous = _soundVolume;
    setState(() {
      _saving = true;
      _soundVolume = value;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'notificationSoundVolume': value},
      );
      await NotificationService().setPreferences(
        notificationsEnabled: _notificationsEnabled,
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        customNotificationsEnabled: _customNotificationsEnabled,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _soundVolume = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save notification volume: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _previewSound() async {
    if (!_soundEnabled || _saving) return;
    try {
      await _previewPlayer.stop();
      await _previewPlayer.setVolume(_soundVolume);
      await _previewPlayer.play(AssetSource('audio/bike_sound.mp3'));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play notification sound: $error')),
        );
      }
    }
  }

  bool _preferenceValue(String field) => switch (field) {
    'notificationsEnabled' => _notificationsEnabled,
    'notificationSoundEnabled' => _soundEnabled,
    'notificationVibrationEnabled' => _vibrationEnabled,
    'customNotificationsEnabled' => _customNotificationsEnabled,
    _ => false,
  };

  void _setPreferenceValue(String field, bool value) {
    switch (field) {
      case 'notificationsEnabled':
        _notificationsEnabled = value;
      case 'notificationSoundEnabled':
        _soundEnabled = value;
      case 'notificationVibrationEnabled':
        _vibrationEnabled = value;
      case 'customNotificationsEnabled':
        _customNotificationsEnabled = value;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.themedBackground,
    appBar: AppBar(
      title: const Text('Notification settings'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PreferenceTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: 'Turn app notifications on or off',
                value: _notificationsEnabled,
                enabled: !_saving,
                onChanged: (value) =>
                    _updatePreference('notificationsEnabled', value),
              ),
              const SizedBox(height: 10),
              _PreferenceTile(
                icon: Icons.volume_up_outlined,
                title: 'Notification sound',
                subtitle: 'Play a sound for notifications',
                value: _soundEnabled,
                enabled: !_saving && _notificationsEnabled,
                onChanged: (value) =>
                    _updatePreference('notificationSoundEnabled', value),
              ),
              if (_soundEnabled) ...[
                const SizedBox(height: 4),
                Material(
                  color: AppColors.themedCard,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sound volume',
                                style: TextStyle(
                                  color: AppColors.themedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Preview notification sound',
                              onPressed: _saving ? null : _previewSound,
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                            Text('${(_soundVolume * 100).round()}%'),
                          ],
                        ),
                        Slider(
                          value: _soundVolume,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          activeColor: AppColors.orange,
                          onChanged: !_saving && _notificationsEnabled
                              ? (value) => setState(() => _soundVolume = value)
                              : null,
                          onChangeEnd: _updateSoundVolume,
                        ),
                        Text(
                          'Adjusts the in-app sound preview. Notification volume may also depend on your device settings.',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _PreferenceTile(
                icon: Icons.vibration,
                title: 'Vibrate',
                subtitle: 'Vibrate when a notification arrives',
                value: _vibrationEnabled,
                enabled: !_saving && _notificationsEnabled,
                onChanged: (value) =>
                    _updatePreference('notificationVibrationEnabled', value),
              ),
              const SizedBox(height: 10),
              _PreferenceTile(
                icon: Icons.campaign_outlined,
                title: 'Custom notifications',
                subtitle: 'Receive announcements and event alerts',
                value: _customNotificationsEnabled,
                enabled: !_saving && _notificationsEnabled,
                onChanged: (value) =>
                    _updatePreference('customNotificationsEnabled', value),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: LinearProgressIndicator(color: AppColors.orange),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 4, right: 4),
                child: Text(
                  'Your device may also block notifications or override sound and vibration in its system settings.',
                  style: TextStyle(fontSize: 12, color: AppColors.themedGrey),
                ),
              ),
            ],
          ),
  );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.themedCard,
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: AppColors.orange),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.themedText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppColors.orange,
      ),
    ),
  );
}
