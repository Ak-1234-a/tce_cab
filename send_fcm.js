const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function main() {
  console.log("🔍 Checking for bookings with pending status...");

  const snapshot = await db.collection("new_bookings").get();

  // Filter documents with pending pickup or drop status
  const pendingBookings = snapshot.docs.filter(doc => {
    const data = doc.data();
    return data.pickup_status === 'pending' || (data.tripType === 'Round Trip' && data.drop_status === 'pending');
  });

  if (pendingBookings.length === 0) {
    console.log("✅ No bookings with pending status.");
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

  for (const doc of pendingBookings) {
    const booking = doc.data();

    // Check for pending pickup booking
    if (booking.pickup_status === 'pending') {
      const message = {
        token: token,
        notification: {
          title: "🔔 Pickup Needs Driver",
          body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} for a Pickup on ${booking.pickupDate || "unknown date"} at ${booking.pickupTime || "unknown time"}. A driver needs to be assigned.`,
        },
        data: {
          bookingId: doc.id,
          bookingType: "Pickup",
          resourcePerson: booking.resourcePerson || "",
          facility: booking.facility || "",
          pickupDate: booking.pickupDate || "",
          pickupTime: booking.pickupTime || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "booking_notifications",
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
        console.log(`✅ Pickup notification for booking ${doc.id} sent:`, response);
      } catch (error) {
        console.error(`❌ Error sending pickup message for booking ${doc.id}:`, error);
      }
    }

    // Check for pending drop booking (for round trips)
    if (booking.tripType === 'Round Trip' && booking.drop_status === 'pending') {
      const message = {
        token: token,
        notification: {
          title: "🔔 Drop Needs Driver",
          body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} for a Drop on ${booking.dropDate || "unknown date"} at ${booking.dropTime || "unknown time"}. A driver needs to be assigned.`,
        },
        data: {
          bookingId: doc.id,
          bookingType: "Drop",
          resourcePerson: booking.resourcePerson || "",
          facility: booking.facility || "",
          dropDate: booking.dropDate || "",
          dropTime: booking.dropTime || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "booking_notifications",
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
        console.log(`✅ Drop notification for booking ${doc.id} sent:`, response);
      } catch (error) {
        console.error(`❌ Error sending drop message for booking ${doc.id}:`, error);
      }
    }
  }
}

main().catch(console.error);
