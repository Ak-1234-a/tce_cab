const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function main() {
  console.log("🔍 Checking for bookings where driverId is not assigned...");

  const snapshot = await db.collection("bookings").get();

  // Filter documents with missing or empty driverId
  const bookingsWithoutDriver = snapshot.docs.filter(doc => {
    const data = doc.data();
    return !data.driverId; // undefined, null, or empty string
  });

  if (bookingsWithoutDriver.length === 0) {
    console.log("✅ No bookings without driverId.");
    return;
  }

  // Get manager FCM token
  const managerDoc = await db.collection("managers").doc("manager").get();
  const managerData = managerDoc.data();

  if (!managerData || !managerData.fcmToken) {
    console.error("❌ No FCM token found for manager.");
    return;
  }

  const token = managerData.fcmToken;

  for (const doc of bookingsWithoutDriver) {
    const booking = doc.data();

    const message = {
      notification: {
        title: "🔔 Booking Needs Driver",
        body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} on ${booking.pickupDate || "unknown date"} at ${booking.pickupTime || "unknown time"}. No driver assigned yet.`,
      },
      data: {
        bookingId: doc.id,
        resourcePerson: booking.resourcePerson || "",
        facility: booking.facility || "",
        pickupDate: booking.pickupDate || "",
        pickupTime: booking.pickupTime || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK", // important for Flutter to detect taps on notification
      },
      token: token,
      android: {
        priority: "high",
        notification: {
          channelId: "booking_notifications", // Make sure your Flutter app defines this channel
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            category: "BOOKING_CATEGORY",
            "thread-id": "booking_thread",
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log("✅ Notification sent:", response);
    } catch (error) {
      console.error("❌ Error sending message:", error);
    }
  }
}

main().catch(console.error);
