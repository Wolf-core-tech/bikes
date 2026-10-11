import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bikers/models/announcement.dart';

void main() {
  test('parses a published ride and its event time zone', () {
    final eventDate = DateTime.utc(2026, 12, 1, 8);
    final announcement = Announcement.fromMap('ride-1', {
      'title': 'Weekend ride',
      'description': 'Meet at the cafe.',
      'category': 'ride',
      'creatorUserId': 'rider-1',
      'creatorDisplayName': 'Rider',
      'eventDateTime': Timestamp.fromDate(eventDate),
      'eventLocalDateTime': '2026-12-01T13:30',
      'timeZone': 'Asia/Kolkata',
      'status': 'published',
      'isPublished': true,
    });

    expect(announcement.id, 'ride-1');
    expect(announcement.category, AnnouncementCategory.ride);
    expect(announcement.eventDateTime?.toUtc(), eventDate);
    expect(announcement.eventLocalDateTime, '2026-12-01T13:30');
    expect(announcement.timeZone, 'Asia/Kolkata');
    expect(announcement.isCancelled, isFalse);
  });

  test('maps categories and RSVP values to stable wire values', () {
    expect(
      announcementCategoryWire(AnnouncementCategory.importantUpdate),
      'important_update',
    );
    expect(announcementRsvpWire(AnnouncementRsvp.notComing), 'not_coming');
    expect(announcementRsvpLabel(AnnouncementRsvp.unsure), 'Not Sure Yet');
  });
}
