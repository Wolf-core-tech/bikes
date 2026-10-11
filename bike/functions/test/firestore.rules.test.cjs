const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} = require("firebase/firestore");

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: "demo-bikes",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, "users", "alice"), {
        uid: "alice",
        name: "Alice",
        email: "alice@example.com",
        phone: "555-0100",
        bikeRegistration: "PRIVATE-123",
      }),
      setDoc(doc(db, "publicProfiles", "alice"), {
        uid: "alice",
        name: "Alice",
        nameLower: "alice",
        photoPath: null,
      }),
      setDoc(doc(db, "publicProfiles", "bob"), {
        uid: "bob",
        name: "Bob",
        nameLower: "bob",
        photoPath: null,
      }),
      setDoc(doc(db, "friendships", "alice_bob"), {
        members: ["alice", "bob"],
        accepted: true,
      }),
      setDoc(doc(db, "friendPresence", "alice"), {
        isOnline: true,
        lastSeen: null,
      }),
      setDoc(doc(db, "users", "alice", "notifications", "friend_request_1"), {
        notificationId: "friend_request_1",
        recipientUserId: "alice",
        type: "friend_request",
        title: "Friend request",
        body: "Bob sent you a friend request.",
        createdAt: new Date(),
        isRead: false,
      }),
      setDoc(doc(db, "squads", "squad"), {
        ownerId: "alice",
        name: "Riders",
        kind: "squad",
      }),
      setDoc(doc(db, "squads", "squad", "members", "alice"), {
        uid: "alice",
        role: "leader",
      }),
      setDoc(doc(db, "squads", "squad", "members", "dave"), {
        uid: "dave",
        role: "coLeader",
      }),
    ]);
  });
});

async function seedAnnouncement(id, overrides = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const data = {
      title: "Weekend ride",
      description: "Join the group ride.",
      category: "ride",
      creatorUserId: "alice",
      creatorDisplayName: "Alice",
      createdAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
      updatedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
      eventDateTime: Timestamp.fromDate(new Date("2026-12-01T08:00:00Z")),
      eventLocalDateTime: "2026-12-01T13:30",
      timeZone: "Asia/Kolkata",
      meetingPlace: "Rider cafe",
      meetingAddress: null,
      latitude: null,
      longitude: null,
      additionalInstructions: null,
      rsvpDeadline: null,
      rsvpDeadlineLocalDateTime: null,
      status: "published",
      publishedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
      isPublished: true,
      cancellationMessage: null,
      ...overrides,
    };
    await setDoc(
      doc(context.firestore(), "announcements", id),
      data,
    );
  });
}

test("a signed-in user cannot read another user's private profile", async () => {
  const db = testEnvironment.authenticatedContext("bob").firestore();
  await assertFails(getDoc(doc(db, "users", "alice")));
});

test("a user can read their own private profile", async () => {
  const db = testEnvironment.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(db, "users", "alice")));
});

test("authenticated users can discover minimal public profiles but cannot write them", async () => {
  const db = testEnvironment.authenticatedContext("bob").firestore();
  await assertSucceeds(getDocs(collection(db, "publicProfiles")));
  await assertFails(setDoc(doc(db, "publicProfiles", "bob"), {
    uid: "bob",
    name: "Impersonated rider",
    nameLower: "impersonated rider",
    photoPath: null,
  }));
});

test("friend presence is readable only by the owner or an accepted friend", async () => {
  const friendDb = testEnvironment.authenticatedContext("bob").firestore();
  const strangerDb = testEnvironment.authenticatedContext("charlie").firestore();
  await assertSucceeds(getDoc(doc(friendDb, "friendPresence", "alice")));
  await assertFails(getDoc(doc(strangerDb, "friendPresence", "alice")));
  await assertFails(getDocs(collection(friendDb, "friendPresence")));
});

test("a user cannot write a plaintext password field to their profile", async () => {
  const db = testEnvironment.authenticatedContext("alice").firestore();
  await assertFails(setDoc(doc(db, "users", "alice"), {
    uid: "alice",
    name: "Alice",
    email: "alice@example.com",
    phone: "555-0100",
    password: "plaintext",
  }));
});

test("notification preferences can only be changed on the owner's profile", async () => {
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const bobDb = testEnvironment.authenticatedContext("bob").firestore();
  await assertSucceeds(updateDoc(doc(aliceDb, "users", "alice"), {
    notificationsEnabled: false,
    notificationSoundEnabled: false,
    notificationVibrationEnabled: true,
    customNotificationsEnabled: false,
  }));
  await assertFails(updateDoc(doc(bobDb, "users", "alice"), {
    notificationsEnabled: false,
  }));
  await assertFails(updateDoc(doc(aliceDb, "users", "alice"), {
    notificationSoundEnabled: "off",
  }));
});

test("notification history is private to the recipient and read status is the only client edit", async () => {
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const bobDb = testEnvironment.authenticatedContext("bob").firestore();
  const aliceNotice = doc(aliceDb, "users", "alice", "notifications", "friend_request_1");
  await assertSucceeds(getDocs(collection(aliceDb, "users", "alice", "notifications")));
  await assertFails(getDoc(doc(bobDb, "users", "alice", "notifications", "friend_request_1")));
  await assertSucceeds(updateDoc(aliceNotice, {isRead: true}));
  await assertFails(updateDoc(aliceNotice, {title: "Changed"}));
});

test("clients cannot forge server notification types or another recipient's notification", async () => {
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  await assertFails(setDoc(
    doc(aliceDb, "users", "alice", "notifications", "forged"),
    {
      notificationId: "forged",
      recipientUserId: "alice",
      type: "friend_request",
      title: "Forged",
      body: "Forged",
      createdAt: serverTimestamp(),
      isRead: false,
    },
  ));
  await assertFails(setDoc(
    doc(aliceDb, "users", "bob", "notifications", "forged"),
    {recipientUserId: "bob"},
  ));
});

test("destination alerts are owner-created once per ride with bounded content", async () => {
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const destinationAlert = {
    notificationId: "destination_ride123",
    recipientUserId: "alice",
    senderUserId: null,
    type: "destination_reached",
    title: "Destination reached!",
    body: "Destination reached: Harbor",
    createdAt: serverTimestamp(),
    isRead: false,
    relatedRideId: "ride123",
  };
  await assertSucceeds(setDoc(
    doc(aliceDb, "users", "alice", "notifications", "destination_ride123"),
    destinationAlert,
  ));
  await assertFails(setDoc(
    doc(aliceDb, "users", "alice", "notifications", "destination_otherRide"),
    {...destinationAlert, notificationId: "destination_otherRide"},
  ));
  await assertFails(setDoc(
    doc(aliceDb, "users", "bob", "notifications", "destination_ride123"),
    {...destinationAlert, recipientUserId: "bob"},
  ));
});

test("published announcements are readable, but only authorized creators can publish", async () => {
  await seedAnnouncement("published");
  const alice = testEnvironment.authenticatedContext("alice").firestore();
  const bob = testEnvironment.authenticatedContext("bob").firestore();
  const anonymous = testEnvironment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(bob, "announcements", "published")));
  await assertSucceeds(getDocs(query(
    collection(bob, "announcements"),
    where("isPublished", "==", true),
  )));
  await assertFails(getDoc(doc(anonymous, "announcements", "published")));

  const announcement = {
    title: "Important update",
    description: "Please read this.",
    category: "important_update",
    creatorUserId: "alice",
    creatorDisplayName: "Alice",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    eventDateTime: null,
    eventLocalDateTime: null,
    timeZone: "Asia/Kolkata",
    meetingPlace: null,
    meetingAddress: null,
    latitude: null,
    longitude: null,
    additionalInstructions: null,
    rsvpDeadline: null,
    rsvpDeadlineLocalDateTime: null,
    status: "published",
    publishedAt: serverTimestamp(),
    isPublished: true,
    cancellationMessage: null,
  };
  await assertFails(setDoc(doc(alice, "announcements", "forged"), announcement));
  const admin = testEnvironment.authenticatedContext(
    "alice",
    {announcementAdmin: true},
  ).firestore();
  await assertSucceeds(setDoc(doc(admin, "announcements", "created"), announcement));
  const incompleteDraft = {
    ...announcement,
    category: "ride",
    eventDateTime: null,
    eventLocalDateTime: null,
    meetingPlace: null,
    status: "draft",
    publishedAt: null,
    isPublished: false,
  };
  await assertSucceeds(setDoc(
    doc(admin, "announcements", "draft"),
    incompleteDraft,
  ));
  await assertFails(updateDoc(doc(admin, "announcements", "draft"), {
    status: "published",
    publishedAt: serverTimestamp(),
    isPublished: true,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(bob, "announcements", "published"), {
    title: "Tampered",
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(admin, "announcements", "published"), {
    title: "Updated weekend ride",
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(admin, "announcements", "published"), {
    status: "cancelled",
    cancellationMessage: "Weather conditions.",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(bob, "announcements", "published"), {
    status: "cancelled",
    updatedAt: serverTimestamp(),
  }));
});

test("announcement RSVPs are unique per user, owner-editable and creator-readable", async () => {
  await seedAnnouncement("published");
  const bob = testEnvironment.authenticatedContext("bob").firestore();
  const charlie = testEnvironment.authenticatedContext("charlie").firestore();
  const admin = testEnvironment.authenticatedContext(
    "alice",
    {admin: true},
  ).firestore();
  const response = doc(
    bob,
    "announcements",
    "published",
    "responses",
    "bob",
  );
  await assertSucceeds(setDoc(response, {
    userId: "bob",
    displayName: "Bob",
    photoPath: null,
    response: "coming",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(response, {
    response: "unsure",
    updatedAt: serverTimestamp(),
  }, {merge: true}));
  await assertFails(getDoc(doc(
    charlie,
    "announcements",
    "published",
    "responses",
    "bob",
  )));
  await assertSucceeds(getDocs(collection(
    admin,
    "announcements",
    "published",
    "responses",
  )));
  await assertFails(setDoc(
    doc(charlie, "announcements", "published", "responses", "bob"),
    {
      userId: "bob",
      displayName: "Bob",
      photoPath: null,
      response: "coming",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
});

test("cancelled announcements cannot accept new RSVPs", async () => {
  await seedAnnouncement("cancelled", {status: "cancelled"});
  const bob = testEnvironment.authenticatedContext("bob").firestore();
  await assertFails(setDoc(
    doc(bob, "announcements", "cancelled", "responses", "bob"),
    {
      userId: "bob",
      displayName: "Bob",
      photoPath: null,
      response: "coming",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
});

test("announcement read markers are private and owner-created", async () => {
  await seedAnnouncement("published");
  const alice = testEnvironment.authenticatedContext("alice").firestore();
  const bob = testEnvironment.authenticatedContext("bob").firestore();
  const aliceRead = doc(alice, "users", "alice", "announcementReads", "published");
  await assertSucceeds(setDoc(aliceRead, {
    announcementId: "published",
    userId: "alice",
    viewedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(
    bob,
    "users",
    "alice",
    "announcementReads",
    "published",
  )));
  await assertFails(setDoc(
    doc(bob, "users", "alice", "announcementReads", "published"),
    {
      announcementId: "published",
      userId: "alice",
      viewedAt: serverTimestamp(),
    },
  ));
});

test("only a squad leader can read and review join requests", async () => {
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const bobDb = testEnvironment.authenticatedContext("bob").firestore();
  const daveDb = testEnvironment.authenticatedContext("dave").firestore();
  const charlieDb = testEnvironment.authenticatedContext("charlie").firestore();
  const erinDb = testEnvironment.authenticatedContext("erin").firestore();
  const requestRef = doc(charlieDb, "squadJoinRequests", "squad_charlie");
  await assertSucceeds(setDoc(requestRef, {
    squadId: "squad",
    squadName: "Riders",
    requesterId: "charlie",
    requesterName: "Charlie",
    status: "pending",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(
    doc(erinDb, "squadJoinRequests", "squad_erin"),
    {
      squadId: "squad",
      squadName: "Riders",
      requesterId: "erin",
      requesterName: "Erin",
      status: "pending",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
  const aliceRequest = doc(aliceDb, "squadJoinRequests", "squad_charlie");
  await assertSucceeds(getDocs(query(
    collection(aliceDb, "squadJoinRequests"),
    where("squadId", "==", "squad"),
  )));
  await assertSucceeds(getDoc(doc(daveDb, "squadJoinRequests", "squad_charlie")));
  await assertSucceeds(updateDoc(doc(daveDb, "squadJoinRequests", "squad_erin"), {
    status: "approved",
    reviewedBy: "dave",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(bobDb, "squadJoinRequests", "squad_charlie")));
  await assertFails(updateDoc(doc(bobDb, "squadJoinRequests", "squad_charlie"), {
    status: "approved",
    reviewedBy: "bob",
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(aliceRequest, {
    status: "rejected",
    reviewedBy: "alice",
    updatedAt: serverTimestamp(),
  }));
});
