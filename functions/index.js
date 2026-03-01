const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * 1. Yangi foydalanuvchi ro'yxatdan o'tganda Firestore'da profil yaratish
 */
exports.createUserProfile = beforeUserCreated((event) => {
    const user = event.data;
    const uid = user.uid;
    const email = user.email || "";
    const displayName = user.displayName || "";
    const photoURL = user.photoURL || "";

    const db = admin.firestore();
    return db.collection("users").doc(uid).set({
        uid: uid,
        username: displayName || email.split("@")[0] || "User_" + uid.substring(0, 4),
        email: email,
        avatar: photoURL,
        bio: "SafeChat orqali muloqotda",
        online: true,
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmToken: "",
    }, { merge: true });
});

/**
 * 2. Yangi xabar kelganda Push-Notification yuborish
 * FILTR: O'ziga yuborilgan xabarlarga bildirishnoma ketmaydi
 */
exports.onMessageCreated = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const message = snap.data();
    const { chatId } = event.params;
    const { senderId, text, type } = message;

    // Chat ID'dan qabul qiluvchini aniqlash
    const userIds = chatId.split("_");
    const receiverId = userIds.find((id) => id !== senderId);

    // 🛑 MUHIM FILTR: Agar qabul qiluvchi topilmasa yoki yuboruvchi bilan bir xil bo'lsa to'xtatish
    if (!receiverId || receiverId === senderId) {
        console.log(`Bildirishnoma bekor qilindi: Sender(${senderId}) va Receiver(${receiverId}) bir xil yoki noto'g'ri.`);
        return null;
    }

    try {
        const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
        if (!receiverDoc.exists) return null;

        const receiverData = receiverDoc.data();
        const token = receiverData.fcmToken;

        // Agar qabul qiluvchida token bo'lmasa yubormaymiz
        if (!token) {
            console.log(`Bildirishnoma yuborilmadi: ${receiverId} uchun FCM Token topilmadi.`);
            return null;
        }

        const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
        const senderName = senderDoc.data()?.username || "Yangi xabar";

        let notificationBody = text;
        if (type === "image") notificationBody = "📷 Rasm yuborildi";

        const payload = {
            token: token,
            notification: {
                title: senderName,
                body: notificationBody.length > 60 ? notificationBody.substring(0, 60) + "..." : notificationBody,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                chatId: chatId,
                senderId: senderId,
                type: "chat_message"
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "cyber_chat_priority_channel",
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        mutableContent: true,
                        threadId: chatId,
                        interruptionLevel: "active"
                    }
                }
            }
        };

        const response = await admin.messaging().send(payload);
        console.log("Bildirishnoma muvaffaqiyatli yuborildi:", response);
        return response;
        
    } catch (error) {
        console.error("Notification Error:", error);
        return null;
    }
});

/**
 * 3. Foydalanuvchi tizimdan chiqqanda online statusini o'chirish
 */
exports.onUserOffline = onCall(async (request) => {
    if (!request.auth) return { status: "error", message: "Ruxsat berilmagan" };

    await admin.firestore().collection("users").doc(request.auth.uid).update({
        online: false,
        lastActive: admin.firestore.FieldValue.serverTimestamp()
    });

    return { status: "success" };
});