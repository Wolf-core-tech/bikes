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
exports.onUserOnline = exports.onMessageCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
/**
 * Triggered when a new message is created in a conversation.
 * Sends a push notification to the receiver(s).
 */
exports.onMessageCreated = functions.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message)
        return;
    const senderId = message.senderId;
    const text = message.text;
    // Get the conversation to find participants
    const convRef = admin.firestore().collection("conversations").doc(context.params.conversationId);
    const convSnap = await convRef.get();
    const convData = convSnap.data();
    if (!convData)
        return;
    const participants = convData.participants || [];
    const participantNames = convData.participantNames || {};
    const senderName = participantNames[senderId] || "A Rider";
    // Find all receivers (everyone in participants array except sender)
    const receivers = participants.filter((p) => p !== senderId);
    if (receivers.length === 0)
        return;
    // Get FCM tokens for all receivers
    const tokens = [];
    for (const receiverId of receivers) {
        const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
        const userData = userSnap.data();
        if (userData && userData.fcmToken) {
            tokens.push(userData.fcmToken);
        }
    }
    if (tokens.length === 0)
        return;
    // Send notifications
    const payload = {
        notification: {
            title: `New message from ${senderName}`,
            body: text,
        },
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            conversationId: context.params.conversationId,
            type: "chat",
        },
    };
    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: payload.notification,
            data: payload.data,
        });
        console.log(`Successfully sent ${response.successCount} messages`);
    }
    catch (error) {
        console.error("Error sending message notification", error);
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
            if (data && data.fcmToken && data.isOnline !== true) {
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
//# sourceMappingURL=index.js.map