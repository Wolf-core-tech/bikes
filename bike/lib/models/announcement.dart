import 'package:cloud_firestore/cloud_firestore.dart';

enum AnnouncementCategory {
  ride,
  meetup,
  communityNews,
  importantUpdate,
  emergency,
}

enum AnnouncementRsvp {
  coming,
  notComing,
  unsure,
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.creatorUserId,
    required this.creatorDisplayName,
    required this.createdAt,
    required this.updatedAt,
    required this.eventDateTime,
    required this.eventLocalDateTime,
    required this.timeZone,
    required this.meetingPlace,
    required this.meetingAddress,
    required this.latitude,
    required this.longitude,
    required this.additionalInstructions,
    required this.rsvpDeadline,
    required this.rsvpDeadlineLocalDateTime,
    required this.status,
    required this.publishedAt,
    required this.isPublished,
    required this.cancellationMessage,
  });

  final String id;
  final String title;
  final String description;
  final AnnouncementCategory category;
  final String creatorUserId;
  final String creatorDisplayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? eventDateTime;
  final String? eventLocalDateTime;
  final String timeZone;
  final String? meetingPlace;
  final String? meetingAddress;
  final double? latitude;
  final double? longitude;
  final String? additionalInstructions;
  final DateTime? rsvpDeadline;
  final String? rsvpDeadlineLocalDateTime;
  final String status;
  final DateTime? publishedAt;
  final bool isPublished;
  final String? cancellationMessage;

  bool get isCancelled => status == 'cancelled';

  factory Announcement.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => Announcement.fromMap(document.id, document.data());

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(Object? value) =>
        value is Timestamp ? value.toDate() : null;

    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: _categoryFromWire(data['category'] as String?),
      creatorUserId: data['creatorUserId'] as String? ?? '',
      creatorDisplayName: data['creatorDisplayName'] as String? ?? 'Rider',
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
      eventDateTime: date(data['eventDateTime']),
      eventLocalDateTime: data['eventLocalDateTime'] as String?,
      timeZone: data['timeZone'] as String? ?? 'UTC',
      meetingPlace: data['meetingPlace'] as String?,
      meetingAddress: data['meetingAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      additionalInstructions: data['additionalInstructions'] as String?,
      rsvpDeadline: date(data['rsvpDeadline']),
      rsvpDeadlineLocalDateTime:
          data['rsvpDeadlineLocalDateTime'] as String?,
      status: data['status'] as String? ?? 'published',
      publishedAt: date(data['publishedAt']),
      isPublished: data['isPublished'] as bool? ?? false,
      cancellationMessage: data['cancellationMessage'] as String?,
    );
  }

  static AnnouncementCategory _categoryFromWire(String? value) =>
      switch (value) {
        'ride' => AnnouncementCategory.ride,
        'meetup' => AnnouncementCategory.meetup,
        'community_news' => AnnouncementCategory.communityNews,
        'important_update' => AnnouncementCategory.importantUpdate,
        'emergency' => AnnouncementCategory.emergency,
        _ => AnnouncementCategory.communityNews,
      };
}

String announcementCategoryLabel(AnnouncementCategory category) =>
    switch (category) {
      AnnouncementCategory.ride => 'Ride',
      AnnouncementCategory.meetup => 'Meetup',
      AnnouncementCategory.communityNews => 'Community news',
      AnnouncementCategory.importantUpdate => 'Important update',
      AnnouncementCategory.emergency => 'Emergency',
    };

String announcementCategoryWire(AnnouncementCategory category) =>
    switch (category) {
      AnnouncementCategory.ride => 'ride',
      AnnouncementCategory.meetup => 'meetup',
      AnnouncementCategory.communityNews => 'community_news',
      AnnouncementCategory.importantUpdate => 'important_update',
      AnnouncementCategory.emergency => 'emergency',
    };

String announcementRsvpWire(AnnouncementRsvp response) => switch (response) {
  AnnouncementRsvp.coming => 'coming',
  AnnouncementRsvp.notComing => 'not_coming',
  AnnouncementRsvp.unsure => 'unsure',
};

String announcementRsvpLabel(AnnouncementRsvp response) =>
    switch (response) {
      AnnouncementRsvp.coming => "I'm Coming",
      AnnouncementRsvp.notComing => 'Not Coming',
      AnnouncementRsvp.unsure => 'Not Sure Yet',
    };
