import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/announcement.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AnnouncementEditorScreen extends StatefulWidget {
  const AnnouncementEditorScreen({super.key, this.announcement});

  final Announcement? announcement;

  @override
  State<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState extends State<AnnouncementEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _place;
  late final TextEditingController _address;
  late final TextEditingController _instructions;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  AnnouncementCategory _category = AnnouncementCategory.ride;
  DateTime? _eventDateTime;
  DateTime? _rsvpDeadline;
  String _timeZone = 'UTC';
  bool _saving = false;

  bool get _requiresEventDetails =>
      _category == AnnouncementCategory.ride ||
      _category == AnnouncementCategory.meetup;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
    final announcement = widget.announcement;
    _title = TextEditingController(text: announcement?.title ?? '');
    _description = TextEditingController(
      text: announcement?.description ?? '',
    );
    _place = TextEditingController(text: announcement?.meetingPlace ?? '');
    _address = TextEditingController(text: announcement?.meetingAddress ?? '');
    _instructions = TextEditingController(
      text: announcement?.additionalInstructions ?? '',
    );
    _latitude = TextEditingController(
      text: announcement?.latitude?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: announcement?.longitude?.toString() ?? '',
    );
    _category = announcement?.category ?? AnnouncementCategory.ride;
    _eventDateTime = _parseWallTime(
      announcement?.eventLocalDateTime,
      announcement?.eventDateTime,
    );
    _rsvpDeadline = _parseWallTime(
      announcement?.rsvpDeadlineLocalDateTime,
      announcement?.rsvpDeadline,
    );
    _timeZone = announcement?.timeZone ?? 'UTC';
    _loadTimeZone();
  }

  DateTime? _parseWallTime(String? wallTime, DateTime? fallback) {
    if (wallTime != null) return DateTime.tryParse(wallTime);
    return fallback?.toLocal();
  }

  Future<void> _loadTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      if (mounted && widget.announcement == null) {
        setState(() => _timeZone = timezone.identifier);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the device time zone; using UTC.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    _address.dispose();
    _instructions.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 1)),
      firstDate: current != null &&
              current.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(current.year, current.month, current.day)
          : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _chooseEventDate() async {
    final value = await _pickDateTime(_eventDateTime);
    if (value != null && mounted) setState(() => _eventDateTime = value);
  }

  Future<void> _chooseRsvpDeadline() async {
    final value = await _pickDateTime(_rsvpDeadline);
    if (value != null && mounted) setState(() => _rsvpDeadline = value);
  }

  String _wallTime(DateTime? value) {
    if (value == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}T${two(value.hour)}:${two(value.minute)}';
  }

  DateTime? _toUtc(DateTime? wallTime) {
    if (wallTime == null) return null;
    final location = tz.getLocation(_timeZone);
    final zoned = tz.TZDateTime(
      location,
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
    );
    if (zoned.year != wallTime.year ||
        zoned.month != wallTime.month ||
        zoned.day != wallTime.day ||
        zoned.hour != wallTime.hour ||
        zoned.minute != wallTime.minute) {
      throw ArgumentError(
        'That local time does not exist because of a daylight-saving change.',
      );
    }
    return zoned.toUtc();
  }

  String _displayTime(DateTime? value) {
    if (value == null) return 'Choose date and time';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour < 12 ? 'AM' : 'PM';
    return '${value.day}/${value.month}/${value.year} • $hour:$minute $meridiem';
  }

  Future<void> _save({required bool publish}) async {
    if (_saving) return;
    if (publish && !_formKey.currentState!.validate()) return;
    if (publish && _requiresEventDetails && _eventDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an event date and time.')),
      );
      return;
    }
    if (publish) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Publish announcement?'),
          content: const Text(
            'This announcement will be available to all eligible riders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final provider = context.read<AnnouncementProvider>();
      final arguments = <String, Object?>{
        'announcementId': widget.announcement?.id,
        'title': _title.text,
        'description': _description.text,
        'category': _category,
        'creatorDisplayName':
            context.read<AuthProvider>().currentUser?.name ?? 'Rider',
        'timeZone': _timeZone,
        'eventDateTime': _toUtc(_eventDateTime),
        'eventLocalDateTime': _wallTime(_eventDateTime),
        'meetingPlace': _place.text,
        'meetingAddress': _address.text,
        'latitude': double.tryParse(_latitude.text.trim()),
        'longitude': double.tryParse(_longitude.text.trim()),
        'additionalInstructions': _instructions.text,
        'rsvpDeadline': _toUtc(_rsvpDeadline),
        'rsvpDeadlineLocalDateTime': _wallTime(_rsvpDeadline),
      };
      if (publish) {
        await provider.publish(
          announcementId: arguments['announcementId'] as String?,
          title: arguments['title']! as String,
          description: arguments['description']! as String,
          category: arguments['category']! as AnnouncementCategory,
          creatorDisplayName: arguments['creatorDisplayName']! as String,
          timeZone: arguments['timeZone']! as String,
          eventDateTime: arguments['eventDateTime'] as DateTime?,
          eventLocalDateTime: arguments['eventLocalDateTime'] as String?,
          meetingPlace: arguments['meetingPlace'] as String?,
          meetingAddress: arguments['meetingAddress'] as String?,
          latitude: arguments['latitude'] as double?,
          longitude: arguments['longitude'] as double?,
          additionalInstructions:
              arguments['additionalInstructions'] as String?,
          rsvpDeadline: arguments['rsvpDeadline'] as DateTime?,
          rsvpDeadlineLocalDateTime:
              arguments['rsvpDeadlineLocalDateTime'] as String?,
        );
      } else {
        await provider.saveDraft(
          announcementId: arguments['announcementId'] as String?,
          title: arguments['title']! as String,
          description: arguments['description']! as String,
          category: arguments['category']! as AnnouncementCategory,
          creatorDisplayName: arguments['creatorDisplayName']! as String,
          timeZone: arguments['timeZone']! as String,
          eventDateTime: arguments['eventDateTime'] as DateTime?,
          eventLocalDateTime: arguments['eventLocalDateTime'] as String?,
          meetingPlace: arguments['meetingPlace'] as String?,
          meetingAddress: arguments['meetingAddress'] as String?,
          latitude: arguments['latitude'] as double?,
          longitude: arguments['longitude'] as double?,
          additionalInstructions:
              arguments['additionalInstructions'] as String?,
          rsvpDeadline: arguments['rsvpDeadline'] as DateTime?,
          rsvpDeadlineLocalDateTime:
              arguments['rsvpDeadlineLocalDateTime'] as String?,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'Announcement published.' : 'Draft saved.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save announcement: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.announcement != null;
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: Text(editing ? 'Edit announcement' : 'Create announcement'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AnnouncementCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Announcement type'),
              items: AnnouncementCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(announcementCategoryLabel(category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Description or message',
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a description.'
                  : null,
            ),
            const SizedBox(height: 8),
            _PickerTile(
              label: _requiresEventDetails
                  ? 'Event date and time (required)'
                  : 'Event date and time (optional)',
              value: _displayTime(_eventDateTime),
              onTap: _chooseEventDate,
              requiredField: _requiresEventDetails,
            ),
            TextFormField(
              controller: _place,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: _requiresEventDetails
                    ? 'Meeting place (required)'
                    : 'Meeting place or destination (optional)',
              ),
              validator: (value) => _requiresEventDetails &&
                      (value == null || value.trim().isEmpty)
                  ? 'Enter a meeting place.'
                  : null,
            ),
            TextFormField(
              controller: _address,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Meeting address (optional)',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitude (optional)',
                    ),
                    validator: (value) => _validateCoordinate(
                      value,
                      minimum: -90,
                      maximum: 90,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitude (optional)',
                    ),
                    validator: (value) => _validateCoordinate(
                      value,
                      minimum: -180,
                      maximum: 180,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PickerTile(
              label: 'RSVP deadline (optional)',
              value: _rsvpDeadline == null
                  ? 'Not set'
                  : _displayTime(_rsvpDeadline),
              onTap: _chooseRsvpDeadline,
              onClear: _rsvpDeadline == null
                  ? null
                  : () => setState(() => _rsvpDeadline = null),
            ),
            Text(
              'Event time zone: $_timeZone',
              style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructions,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Additional instructions (optional)',
              ),
            ),
            if (_requiresEventDetails && _eventDateTime == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Ride and meetup announcements require an event date and time.',
                  style: TextStyle(color: AppColors.orange),
                ),
              ),
            if (_saving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(color: AppColors.orange),
                ),
              )
            else ...[
              const SizedBox(height: 16),
              if (!editing || !widget.announcement!.isPublished)
                OutlinedButton.icon(
                  onPressed: () => _save(publish: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save as draft'),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _save(publish: true),
                icon: const Icon(Icons.campaign_outlined),
                label: Text(editing ? 'Save and publish' : 'Publish announcement'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateCoordinate(
    String? value, {
    required double minimum,
    required double maximum,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final coordinate = double.tryParse(value.trim());
    if (coordinate == null || coordinate < minimum || coordinate > maximum) {
      return 'Enter a value from $minimum to $maximum.';
    }
    return null;
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.requiredField = false,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool requiredField;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    title: Text(label),
    subtitle: Text(value),
    leading: Icon(
      Icons.event_outlined,
      color: requiredField ? AppColors.orange : AppColors.themedGrey,
    ),
    trailing: onClear == null
        ? const Icon(Icons.chevron_right)
        : IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
    onTap: onTap,
  );
}
