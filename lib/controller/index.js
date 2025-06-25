const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendChatNotification = functions.https.onCall(async (data, context) => {
  const { token, message } = data;

  const payload = {
    notification: {
      title: "New Message",
      body: message,
    },
    android: {
      priority: "high",
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  try {
    const response = await admin.messaging().sendToDevice(token, payload);
    return { success: true, response };
  } catch (error) {
    console.error("FCM send failed:", error);
    throw new functions.https.HttpsError("internal", "Failed to send notification");
  }
});
