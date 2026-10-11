"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.findRiderByEmail = exports.backfillPublicProfiles = exports.syncFriendPresence = exports.syncPublicProfile = exports.onUserOnline = exports.onSquadJoinRequestUpdated = exports.onSquadJoinRequestCreated = exports.onSquadMemberAdded = exports.onMessageCreated = exports.onFriendRequestUpdated = exports.onFriendRequestCreated = exports.onAnnouncementUpdated = exports.onAnnouncementCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
function notificationChannelId(channelId, soundEnabled, vibrationEnabled) {
    return `${channelId}${soundEnabled ? "" : "_silent"}${vibrationEnabled ? "" : "_no_vibration"}`;
}
async function createNotification(recipientUserId, notificationId, payload) {
    if (!recipientUserId)
        return;
    const firestore = admin.firestore();
    const notificationRef = firestore.collection("users")
        .doc(recipientUserId).collection("notifications").doc(notificationId);
    const wasCreated = await firestore.runTransaction(async (transaction) => {
        const existing = await transaction.get(notificationRef);
        if (existing.exists)
            return false;
        transaction.create(notificationRef, {
            notificationId,
            recipientUserId,
            senderUserId: payload.senderUserId ?? null,
            type: payload.type,
            title: payload.title.slice(0, 100),
            body: payload.body.slice(0, 500),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            relatedUserId: payload.relatedUserId ?? null,
            relatedSquadId: payload.relatedSquadId ?? null,
            relatedChatId: payload.relatedChatId ?? null,
            relatedRideId: payload.relatedRideId ?? null,
            requestId: payload.requestId ?? null,
            senderPhotoPath: payload.senderPhotoPath ?? null,
            status: payload.status ?? "pending",
        });
        return true;
    });
    if (!wasCreated)
        return;
    const user = await firestore.collection("users").doc(recipientUserId).get();
    const userData = user.data();
    if (!userData || userData.notificationsEnabled === false ||
        (payload.type === "announcement" &&
            userData.customNotificationsEnabled === false))
        return;
    const token = userData.fcmToken;
    if (typeof token !== "string" || token.length === 0)
        return;
    const data = {
        notificationId,
        recipientUserId,
        type: payload.type,
        title: payload.title.slice(0, 100),
        body: payload.body.slice(0, 500),
    };
    for (const [key, value] of Object.entries({
        senderUserId: payload.senderUserId,
        relatedUserId: payload.relatedUserId,
        relatedSquadId: payload.relatedSquadId,
        relatedChatId: payload.relatedChatId,
        relatedRideId: payload.relatedRideId,
        requestId: payload.requestId,
    })) {
        if (value)
            data[key] = value;
    }
    const channelId = payload.type.startsWith("friend_request")
        ? "bikes_friend_requests"
        : payload.type === "chat_message"
            ? "bikes_messages"
            : payload.type === "destination_reached"
                ? "bikes_ride_alerts"
                : "bikes_squads";
    const soundEnabled = userData.notificationSoundEnabled !== false;
    const vibrationEnabled = userData.notificationVibrationEnabled !== false;
    await admin.messaging().send({
        token,
        data,
        android: {
            priority: "high",
            notification: {
                channelId: notificationChannelId(channelId, soundEnabled, vibrationEnabled),
                title: payload.title.slice(0, 100),
                body: payload.body.slice(0, 500),
            },
        },
        apns: {
            headers: { "apns-priority": "5", "apns-push-type": "background" },
            payload: {
                aps: {
                    "content-available": 1,
                    ...(soundEnabled ? { sound: "default" } : {}),
                },
            },
        },
    });
}
async function sendAnnouncementBroadcast(announcementId, eventKey, data, eventKind) {
    const firestore = admin.firestore();
    const deliveryRef = firestore.collection("announcementDeliveries")
        .doc(`${announcementId}_${eventKey}`);
    const claimed = await firestore.runTransaction(async (transaction) => {
        const current = await transaction.get(deliveryRef);
        if (current.exists)
            return false;
        transaction.create(deliveryRef, {
            announcementId,
            eventKey,
            status: "sending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
    });
    if (!claimed)
        return;
    const title = typeof data.title === "string" ? data.title.slice(0, 100) : "BIKES announcement";
    const eventDate = data.eventDateTime?.toDate?.();
    const dateText = eventDate
        ? ` • ${eventDate.toLocaleString("en-US", { timeZone: data.timeZone ?? "UTC", dateStyle: "medium", timeStyle: "short" })}`
        : "";
    const placeText = typeof data.meetingPlace === "string" && data.meetingPlace
        ? ` • ${data.meetingPlace.slice(0, 80)}`
        : "";
    const notificationTitle = eventKind === "cancelled"
        ? `Cancelled: ${title}`
        : eventKind === "updated"
            ? `Event updated: ${title}`
            : title;
    const body = eventKind === "cancelled"
        ? (typeof data.cancellationMessage === "string" && data.cancellationMessage
            ? data.cancellationMessage
            : "This event has been cancelled.")
        : `${typeof data.description === "string" ? data.description.replace(/\s+/g, " ").slice(0, 150) : ""}${dateText}${placeText}`.slice(0, 500);
    const pushData = {
        type: "announcement",
        announcementId,
        eventKey,
        notificationId: `announcement_${announcementId}_${eventKey}`,
        eventKind,
        title: notificationTitle,
        body: body || "Open BIKES to view the announcement.",
    };
    let lastUserId;
    try {
        while (true) {
            let query = firestore.collection("users")
                .orderBy(admin.firestore.FieldPath.documentId())
                .limit(500);
            if (lastUserId)
                query = query.startAfter(lastUserId);
            const page = await query.get();
            if (page.empty)
                break;
            lastUserId = page.docs[page.docs.length - 1].id;
            const eligible = page.docs.filter((user) => {
                const userData = user.data();
                return typeof userData.fcmToken === "string" &&
                    userData.fcmToken.length > 0 &&
                    userData.notificationsEnabled !== false &&
                    userData.customNotificationsEnabled !== false &&
                    userData.announcementNotificationsEnabled === true &&
                    userData.isDeleted !== true;
            });
            const preferenceGroups = new Map();
            for (const recipient of eligible) {
                const userData = recipient.data();
                const soundEnabled = userData.notificationSoundEnabled !== false;
                const vibrationEnabled = userData.notificationVibrationEnabled !== false;
                const key = `${soundEnabled}_${vibrationEnabled}`;
                const group = preferenceGroups.get(key) ?? [];
                group.push(recipient);
                preferenceGroups.set(key, group);
            }
            for (const recipientsGroup of preferenceGroups.values()) {
                const preferences = recipientsGroup[0].data();
                const soundEnabled = preferences.notificationSoundEnabled !== false;
                const vibrationEnabled = preferences.notificationVibrationEnabled !== false;
                for (let index = 0; index < recipientsGroup.length; index += 500) {
                    const recipients = recipientsGroup.slice(index, index + 500);
                    if (recipients.length === 0)
                        continue;
                    const response = await admin.messaging().sendEachForMulticast({
                        tokens: recipients.map((user) => user.data().fcmToken),
                        notification: { title: pushData.title, body: pushData.body },
                        data: pushData,
                        android: {
                            priority: "high",
                            notification: {
                                channelId: notificationChannelId("bikes_announcements", soundEnabled, vibrationEnabled),
                                tag: `announcement_${announcementId}`,
                            },
                        },
                        apns: {
                            headers: { "apns-priority": "10" },
                            payload: {
                                aps: soundEnabled ? { sound: "default" } : {},
                            },
                        },
                    });
                    const invalidTokens = firestore.batch();
                    let hasInvalidTokens = false;
                    response.responses.forEach((result, recipientIndex) => {
                        const code = result.error?.code;
                        if (code === "messaging/registration-token-not-registered" ||
                            code === "messaging/invalid-registration-token") {
                            invalidTokens.update(recipients[recipientIndex].ref, {
                                fcmToken: admin.firestore.FieldValue.delete(),
                            });
                            hasInvalidTokens = true;
                        }
                    });
                    if (hasInvalidTokens)
                        await invalidTokens.commit();
                }
            }
            if (page.size < 500)
                break;
        }
        await deliveryRef.update({
            status: "sent",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        await deliveryRef.delete();
        throw error;
    }
}
exports.onAnnouncementCreated = functions.runWith({ failurePolicy: true })
    .firestore.document("announcements/{announcementId}")
    .onCreate(async (snapshot, context) => {
    const announcement = snapshot.data();
    if (!announcement.isPublished || announcement.status !== "published")
        return;
    await sendAnnouncementBroadcast(context.params.announcementId, "published", announcement, "published");
});
exports.onAnnouncementUpdated = functions.runWith({ failurePolicy: true })
    .firestore.document("announcements/{announcementId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!after.isPublished || before.status === "cancelled")
        return;
    const wasPublished = before.isPublished === true;
    const cancelled = after.status === "cancelled";
    const significantFields = [
        "title",
        "description",
        "eventDateTime",
        "eventLocalDateTime",
        "timeZone",
        "meetingPlace",
        "meetingAddress",
        "latitude",
        "longitude",
        "additionalInstructions",
        "rsvpDeadline",
        "category",
    ];
    const significantChange = significantFields.some((field) => JSON.stringify(before[field] ?? null) !== JSON.stringify(after[field] ?? null));
    if (!wasPublished) {
        if (after.status !== "published")
            return;
        await sendAnnouncementBroadcast(context.params.announcementId, "published", after, "published");
        return;
    }
    if (cancelled) {
        await sendAnnouncementBroadcast(context.params.announcementId, `cancelled_${change.after.updateTime.toMillis()}`, after, "cancelled");
    }
    else if (significantChange && after.status === "published") {
        await sendAnnouncementBroadcast(context.params.announcementId, `updated_${change.after.updateTime.toMillis()}`, after, "updated");
    }
});
exports.onFriendRequestCreated = functions.firestore
    .document("friendRequests/{requestId}")
    .onCreate(async (snapshot, context) => {
    const request = snapshot.data();
    const recipientId = typeof request.receiverId === "string" ? request.receiverId : "";
    const senderId = typeof request.senderId === "string" ? request.senderId : "";
    if (!recipientId || !senderId || recipientId === senderId)
        return;
    const sender = await admin.firestore().collection("publicProfiles").doc(senderId).get();
    const senderName = typeof request.senderName === "string"
        ? request.senderName.slice(0, 100)
        : sender.data()?.name ?? "A rider";
    await createNotification(recipientId, `friend_request_${context.params.requestId}`, {
        senderUserId: senderId,
        relatedUserId: senderId,
        requestId: context.params.requestId,
        senderPhotoPath: sender.data()?.photoPath ?? null,
        type: "friend_request",
        title: "Friend request",
        body: `${senderName} sent you a friend request.`,
        status: "pending",
    });
});
exports.onFriendRequestUpdated = functions.firestore
    .document("friendRequests/{requestId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status || !["accepted", "rejected"].includes(after.status))
        return;
    const senderId = typeof after.senderId === "string" ? after.senderId : "";
    const receiverId = typeof after.receiverId === "string" ? after.receiverId : "";
    const baseId = `friend_request_${context.params.requestId}`;
    if (receiverId) {
        await admin.firestore().collection("users").doc(receiverId)
            .collection("notifications").doc(baseId).set({
            status: after.status,
            isRead: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    if (!senderId)
        return;
    const receiver = await admin.firestore().collection("publicProfiles").doc(receiverId).get();
    const receiverName = receiver.data()?.name ?? "A rider";
    const accepted = after.status === "accepted";
    await createNotification(senderId, `friend_result_${context.params.requestId}`, {
        senderUserId: receiverId,
        relatedUserId: receiverId,
        requestId: context.params.requestId,
        type: "friend_request_result",
        title: accepted ? "Friend request accepted" : "Friend request declined",
        body: accepted
            ? `${receiverName} accepted your friend request.`
            : `${receiverName} declined your friend request.`,
        status: after.status,
    });
});
exports.onMessageCreated = functions.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message || typeof message.senderId !== "string")
        return;
    const conversation = await admin.firestore()
        .collection("conversations").doc(context.params.conversationId).get();
    const data = conversation.data();
    if (!data)
        return;
    const participants = Array.isArray(data.participants)
        ? data.participants.filter((id) => typeof id === "string")
        : [];
    if (!participants.includes(message.senderId))
        return;
    const senderId = message.senderId;
    const senderProfile = await admin.firestore().collection("publicProfiles").doc(senderId).get();
    const participantNames = data.participantNames ?? {};
    const senderName = typeof message.senderName === "string"
        ? message.senderName.slice(0, 100)
        : participantNames[senderId] ?? senderProfile.data()?.name ?? "A rider";
    const squad = data.kind === "squad" && typeof data.squadId === "string"
        ? await admin.firestore().collection("squads").doc(data.squadId).get()
        : null;
    const preview = typeof message.text === "string"
        ? message.text.replace(/\s+/g, " ").slice(0, 120)
        : "Sent you a message.";
    const squadName = squad?.data()?.name ?? data.title ?? "Squad";
    await Promise.all(participants
        .filter((recipientId) => recipientId !== senderId)
        .map((recipientId) => createNotification(recipientId, `message_${context.params.messageId}_${recipientId}`, {
        senderUserId: senderId,
        relatedUserId: senderId,
        relatedSquadId: typeof data.squadId === "string" ? data.squadId : null,
        relatedChatId: context.params.conversationId,
        senderPhotoPath: senderProfile.data()?.photoPath ?? null,
        type: "chat_message",
        title: data.kind === "squad"
            ? `${squadName}: ${senderName}`
            : `Message from ${senderName}`,
        body: preview,
    })));
});
exports.onSquadMemberAdded = functions.firestore
    .document("squads/{squadId}/members/{memberId}")
    .onCreate(async (snapshot, context) => {
    const memberId = context.params.memberId;
    const squad = await admin.firestore().collection("squads").doc(context.params.squadId).get();
    const squadData = squad.data();
    if (!squadData)
        return;
    const squadName = typeof squadData.name === "string" ? squadData.name : "a squad";
    await admin.firestore().collection("users").doc(memberId)
        .collection("squads").doc(context.params.squadId).set({
        squadId: context.params.squadId,
        name: squadName,
    }, { merge: true });
    const conversation = admin.firestore().collection("conversations")
        .doc(`squad_${context.params.squadId}`);
    const chat = await conversation.get();
    if (chat.exists) {
        await conversation.update({
            participants: admin.firestore.FieldValue.arrayUnion(memberId),
            [`unreadCounts.${memberId}`]: 0,
        });
    }
    const joinRequest = await admin.firestore()
        .collection("squadJoinRequests")
        .doc(`${context.params.squadId}_${memberId}`)
        .get();
    if (squadData.ownerId === memberId || joinRequest.data()?.status === "approved")
        return;
    const addedBy = typeof squadData.ownerId === "string" ? squadData.ownerId : null;
    const ownerProfile = addedBy
        ? await admin.firestore().collection("publicProfiles").doc(addedBy).get()
        : null;
    const addedByName = ownerProfile?.data()?.name ?? "Your squad leader";
    await createNotification(memberId, `squad_added_${context.params.squadId}_${memberId}`, {
        senderUserId: addedBy,
        relatedUserId: addedBy,
        relatedSquadId: context.params.squadId,
        type: "squad_member_added",
        title: `Added to ${squadName}`,
        body: `${addedByName} added you to ${squadName}.`,
    });
});
exports.onSquadJoinRequestCreated = functions.firestore
    .document("squadJoinRequests/{requestId}")
    .onCreate(async (snapshot, context) => {
    const request = snapshot.data();
    const squadId = typeof request.squadId === "string" ? request.squadId : "";
    const requesterId = typeof request.requesterId === "string" ? request.requesterId : "";
    if (!squadId || !requesterId)
        return;
    const [squad, requester] = await Promise.all([
        admin.firestore().collection("squads").doc(squadId).get(),
        admin.firestore().collection("publicProfiles").doc(requesterId).get(),
    ]);
    if (!squad.exists)
        return;
    const squadData = squad.data();
    const members = await squad.ref.collection("members").get();
    const leaders = members.docs
        .filter((member) => ["leader", "coLeader"].includes(member.data().role))
        .map((member) => member.id);
    if (typeof squadData.ownerId === "string")
        leaders.push(squadData.ownerId);
    const recipients = [...new Set(leaders)].filter((uid) => uid !== requesterId);
    const requesterName = requester.data()?.name ?? request.requesterName ?? "A rider";
    await Promise.all(recipients.map((recipientId) => createNotification(recipientId, `squad_join_${context.params.requestId}_${recipientId}`, {
        senderUserId: requesterId,
        relatedUserId: requesterId,
        relatedSquadId: squadId,
        requestId: context.params.requestId,
        senderPhotoPath: requester.data()?.photoPath ?? null,
        type: "squad_join_request",
        title: `Join request: ${squadData.name ?? "Squad"}`,
        body: `${requesterName} requested to join ${squadData.name ?? "the squad"}.`,
        status: "pending",
    })));
});
exports.onSquadJoinRequestUpdated = functions.firestore
    .document("squadJoinRequests/{requestId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status || !["approved", "rejected"].includes(after.status))
        return;
    const requesterId = typeof after.requesterId === "string" ? after.requesterId : "";
    const squadId = typeof after.squadId === "string" ? after.squadId : "";
    if (!requesterId || !squadId)
        return;
    const squad = await admin.firestore().collection("squads").doc(squadId).get();
    const approved = after.status === "approved";
    if (approved && squad.exists) {
        await admin.firestore().collection("users").doc(requesterId)
            .collection("squads").doc(squadId).set({
            squadId,
            name: squad.data()?.name ?? "Squad",
        }, { merge: true });
    }
    await createNotification(requesterId, `squad_join_result_${context.params.requestId}`, {
        senderUserId: typeof after.reviewedBy === "string" ? after.reviewedBy : null,
        relatedSquadId: squadId,
        requestId: context.params.requestId,
        type: "squad_join_result",
        title: approved ? "Squad request approved" : "Squad request declined",
        body: approved
            ? `Your request to join ${squad.data()?.name ?? "the squad"} was approved.`
            : `Your request to join ${squad.data()?.name ?? "the squad"} was declined.`,
        status: after.status,
    });
    const leaderMembers = await squad.ref.collection("members")
        .where("role", "in", ["leader", "coLeader"]).get();
    const leaderIds = new Set(leaderMembers.docs.map((leader) => leader.id));
    if (typeof squad.data()?.ownerId === "string") {
        leaderIds.add(squad.data().ownerId);
    }
    for (const leaderId of leaderIds) {
        await admin.firestore().collection("users").doc(leaderId)
            .collection("notifications")
            .doc(`squad_join_${context.params.requestId}_${leaderId}`)
            .set({ status: after.status, isRead: true }, { merge: true });
    }
});
/**
 * Triggered when a user's document is updated.
 * Used to detect when a user comes online to notify their friends.
 */
exports.onUserOnline = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const wasOnline = beforeData.isOnline === true;
    const isOnline = afterData.isOnline === true;
    // Only trigger if they just came online
    if (wasOnline || !isOnline)
        return;
    const userId = context.params.userId;
    const userName = afterData.name || "A friend";
    // 1. Find all friendships containing this user
    const friendshipsSnap = await admin.firestore()
        .collection("friendships")
        .where("members", "array-contains", userId)
        .get();
    if (friendshipsSnap.empty)
        return;
    // Extract friend IDs
    const friendIds = [];
    friendshipsSnap.forEach((doc) => {
        const members = doc.data().members || [];
        const otherId = members.find((id) => id !== userId);
        if (otherId) {
            friendIds.push(otherId);
        }
    });
    if (friendIds.length === 0)
        return;
    // 2. Fetch FCM tokens for those friends
    const tokens = [];
    // Process in batches of 10 to avoid too many parallel queries
    for (let i = 0; i < friendIds.length; i += 10) {
        const batch = friendIds.slice(i, i + 10);
        const userSnaps = await Promise.all(batch.map(id => admin.firestore().collection("users").doc(id).get()));
        for (const snap of userSnaps) {
            const data = snap.data();
            if (data && data.fcmToken && data.isOnline !== true &&
                data.notificationsEnabled !== false) {
                // Send notification only if the friend themselves is not currently online in the app? 
                // (Optional: right now we'll just send to everyone who has a token)
                tokens.push(data.fcmToken);
            }
        }
    }
    if (tokens.length === 0)
        return;
    // 3. Send Notification
    const payload = {
        notification: {
            title: "Friend Online",
            body: `${userName} just came online!`,
        },
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            friendId: userId,
            type: "online_status",
        },
    };
    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: payload.notification,
            data: payload.data,
        });
        console.log(`Successfully sent ${response.successCount} online notifications`);
    }
    catch (error) {
        console.error("Error sending online notifications", error);
    }
});
/**
 * Mirrors only discoverable rider fields into a separate, non-sensitive
 * directory. The private users collection remains owner-readable.
 */
function publicProfile(userId, profile) {
    const name = typeof profile.name === "string"
        ? profile.name.slice(0, 100)
        : "Rider";
    return {
        uid: userId,
        name,
        nameLower: name.trim().toLowerCase(),
        photoPath: typeof profile.photoPath === "string" ? profile.photoPath : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
}
exports.syncPublicProfile = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
    const profileRef = admin.firestore()
        .collection("publicProfiles")
        .doc(context.params.userId);
    if (!change.after.exists) {
        await profileRef.delete();
        return;
    }
    const profile = change.after.data();
    if (!profile)
        return;
    await profileRef.set(publicProfile(context.params.userId, profile));
});
/**
 * Keeps friend-only presence outside private user documents.
 */
exports.syncFriendPresence = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
    const presenceRef = admin.firestore().collection("friendPresence")
        .doc(context.params.userId);
    if (!change.after.exists) {
        await presenceRef.delete();
        return;
    }
    const data = change.after.data();
    await presenceRef.set({
        isOnline: data?.isOnline === true,
        lastSeen: data?.lastSeen ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
});
/**
 * One-time migration for existing users. Only trusted administrators can run
 * it; client-readable directory documents contain no private account fields.
 */
exports.backfillPublicProfiles = functions.https.onCall(async (_data, context) => {
    if (!context.auth?.token.admin) {
        throw new functions.https.HttpsError("permission-denied", "Administrator access is required.");
    }
    const firestore = admin.firestore();
    const users = firestore.collection("users");
    let cursor;
    let processed = 0;
    while (true) {
        let query = users.orderBy(admin.firestore.FieldPath.documentId()).limit(400);
        if (cursor)
            query = query.startAfter(cursor);
        const page = await query.get();
        if (page.empty)
            break;
        const batch = firestore.batch();
        for (const user of page.docs) {
            batch.set(firestore.collection("publicProfiles").doc(user.id), publicProfile(user.id, user.data()));
            processed++;
        }
        await batch.commit();
        cursor = page.docs[page.docs.length - 1];
    }
    return { processed };
});
/**
 * Allows exact-email friend discovery without publishing users' email
 * addresses in the client-readable profile directory.
 */
exports.findRiderByEmail = functions.https.onCall(async (data, context) => {
    const callerId = context.auth?.uid;
    if (!callerId) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in to search for riders.");
    }
    const email = typeof data?.email === "string" ? data.email.trim().toLowerCase() : "";
    if (email.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        throw new functions.https.HttpsError("invalid-argument", "Enter a valid email address.");
    }
    const now = Date.now();
    const firestore = admin.firestore();
    const throttleRef = firestore.collection("securityRateLimits").doc(callerId);
    await firestore.runTransaction(async (transaction) => {
        const throttle = await transaction.get(throttleRef);
        const record = throttle.data();
        const windowStartedAt = Number(record?.windowStartedAt || 0);
        const requestCount = Number(record?.requestCount || 0);
        const inWindow = now - windowStartedAt < 60000;
        if (inWindow && requestCount >= 20) {
            throw new functions.https.HttpsError("resource-exhausted", "Too many rider searches. Try again in a minute.");
        }
        transaction.set(throttleRef, {
            windowStartedAt: inWindow ? windowStartedAt : now,
            requestCount: inWindow ? requestCount + 1 : 1,
            expiresAt: admin.firestore.Timestamp.fromMillis(now + 120000),
        });
    });
    let firebaseUser;
    try {
        firebaseUser = await admin.auth().getUserByEmail(email);
    }
    catch (error) {
        if (error.code === "auth/user-not-found")
            return null;
        throw error;
    }
    const user = await firestore.collection("users").doc(firebaseUser.uid).get();
    const profile = user.data() ?? {};
    return {
        uid: firebaseUser.uid,
        name: typeof profile.name === "string"
            ? profile.name.slice(0, 100)
            : firebaseUser.displayName?.slice(0, 100) ?? "Rider",
        photoPath: typeof profile.photoPath === "string" ? profile.photoPath : null,
    };
});
//# sourceMappingURL=index.js.map