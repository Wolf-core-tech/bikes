# bikers

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Private rider profiles

Firestore `/users/{uid}` documents are private to their owner. Authenticated
rider discovery uses the server-maintained `/publicProfiles/{uid}` directory,
which contains only a rider's display name and profile-photo storage path.
Friend presence is maintained separately and is readable only by the owner and
accepted friends.

Deploy the rules and Cloud Functions before releasing a client that uses the
directory:

```sh
firebase deploy --only firestore:rules,functions --project bikes-b6d74
```

Existing users must be copied into the public directory once after deployment.
From a trusted administrative client, call the `backfillPublicProfiles`
callable while signed in as an account with the Firebase custom claim
`admin: true`. The callable rejects non-admin users; never grant this claim
from the mobile client. Subsequent profile changes are synchronized
automatically by the deployed function.

Run the Firestore authorization tests from `functions/` with:

```sh
npm ci
npm run test:rules
```

## App notifications

The app stores notification history under
`users/{uid}/notifications/{notificationId}`. Firestore rules restrict reads
and read-status updates to the recipient; event records are created by trusted
Cloud Functions. Destination-reached records are the only notification type
the signed-in client may create, and their IDs are stable per tracked ride.
Messages and notifications are data-driven on Android so the Flutter client
can use the app's separately configured notification channels without showing
a second foreground alert.

Build the Cloud Functions, then deploy Firestore rules, indexes, and functions
from the project root:

```sh
cd functions
npm ci
npm run build
cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions --project bikes-b6d74
```

Install and run the Android app:

```sh
flutter pub get
flutter run -d android
```

The app requests Android 13+ notification permission at startup. Users can
later change permission, sound, vibration, or channel importance in Android
Settings; Android controls whether a channel can show heads-up alerts. A
reinstall or clearing app data is needed to recreate channels after changing
their initial importance during testing. Confirm Firebase Cloud Messaging is
enabled for the Firebase project and that the Android app's existing
`google-services.json` belongs to that same project. Deploy the Functions
before sending test events. No Admin credentials or secrets belong in the app.

To exercise the feature on two signed-in Android devices:

1. Allow notification permission on both devices. In the app, open **Discover
   squads** on one device and request to join a squad owned by the other; check
   the leader's in-app and Android notifications, then approve or reject and
   check the requester's result notification.
2. Send a friend request from one device and accept/reject it from the other.
   Verify the requester's result and recipient's unread badge update.
3. Open a direct chat between friends and send a message in foreground,
   background, then with the recipient app terminated. Repeat in a squad chat.
   Tap a system notification and verify it opens the originating chat.
4. Add a registered user to a squad using the existing invitation flow. Verify
   the new member gets one notification and the squad details open from it.
5. Start a ride with a destination, keep location permission enabled, and
   allow three fresh GPS fixes within the destination geofence (up to 80 m,
   constrained by the reported GPS accuracy). Verify exactly one local alert
   and one in-app history item for that ride. Opening the map or refreshing
   alone does not emit a destination alert.
6. Mark one notification and then all notifications as read. Verify the live
   bell badge and unread markers clear. Repeat with notification permission
   denied to confirm in-app history remains available.

The Firestore emulator tests cover notification privacy/read permissions,
public-directory boundaries, squad request authorization, and profile access:

```sh
cd functions
npm ci
npm run test:rules
```

Android may delay or suppress background notifications due to user-disabled
channels, battery restrictions, Do Not Disturb, network availability, or an
OS force-stop. An app force-stopped from Android Settings will not receive
background FCM until the user launches it again. Ride destination detection
uses the existing foreground ride GPS stream and intentionally does not request
background location access.

## Platform-wide ride announcements

Announcements are stored once in `/announcements/{announcementId}`.
Authenticated users can read published announcements and create, publish, and
manage their own announcements and drafts. Draft reads, edits, cancellation,
and draft deletion remain limited to the announcement creator. Published
events stay in the feed when cancelled.

Responses live at
`/announcements/{announcementId}/responses/{userId}`; each signed-in rider can
write only their own response. Only the authorized announcement creator can
read the complete attendee list. View markers are stored per user under
`/users/{uid}/announcementReads/`, separate from the notification bell.
Announcement push delivery is performed by Cloud Functions in batches using
registered FCM tokens. The app records whether Android/iOS notification
permission is enabled; delivery targets active user documents with an FCM
token and that permission flag.

Deploy the rules, indexes and functions after building functions as described
above. Existing users should launch the updated app once while signed in so
their notification-permission setting and refreshed FCM token are saved. For a
trusted announcement creator, assign the custom claim with the Admin SDK; do
not expose service credentials in the Flutter app. Validate publication,
critical event edits, cancellation, RSVP changes and notification taps on real
Android devices using the same two-device steps above.

Notification preferences are available from Settings → Notifications and
from the settings icon on the notification history screen. The master switch
controls push and local alerts; sound and vibration select Android notification
channels with the requested behavior. Custom notifications controls announcement
and event-alert delivery. Android users can still override these choices in
system notification settings.
