const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function main() {
  console.log("🔍 Checking for bookings with Pending status...");

  const managerDoc = await db.collection("new_managers").doc("manager").get();
  const managerData = managerDoc.data();

  if (!managerData || !managerData.fcmToken) {
    console.error("❌ No FCM token found for manager.");
    return;
  }

  const token = managerData.fcmToken;

  const snapshot = await db.collection("new_bookings").get();

  // Filter documents with Pending pickup or drop status and check notification sent status
  const PendingBookings = snapshot.docs.filter(doc => {
    const data = doc.data();
    const isPickupPending = data.pickup_status === 'Pending' && !data.pickupNotificationSent;
    const isDropPending = data.tripType === 'Round Trip' && data.drop_status === 'Pending' && !data.dropNotificationSent;

    return isPickupPending || isDropPending;
  });

  if (PendingBookings.length === 0) {
    console.log("✅ No new pending bookings to notify for.");
    return;
  }

  console.log(`Found ${PendingBookings.length} new pending bookings. Sending notifications...`);

  for (const doc of PendingBookings) {
    const booking = doc.data();
    const bookingId = doc.id;

    // Check for Pending pickup booking
    if (booking.pickup_status === 'Pending' && !booking.pickupNotificationSent) {
      const message = {
        token: token,
        notification: {
          title: "🔔 Pickup Needs Driver",
          body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} for a Pickup on ${booking.pickupDate || "unknown date"} at ${booking.pickupTime || "unknown time"}. A driver needs to be assigned.`,
        },
        data: {
          bookingId: bookingId,
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
        await messaging.send(message);
        console.log(`✅ Pickup notification for booking ${bookingId} sent.`);

        // Update the booking document to mark notification as sent
        await db.collection("new_bookings").doc(bookingId).update({
          pickupNotificationSent: true,
          pickupNotificationSentAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Updated booking ${bookingId} to prevent duplicate pickup notifications.`);

      } catch (error) {
        console.error(`❌ Error sending pickup message for booking ${bookingId}:`, error);
      }
    }

    // Check for Pending drop booking (for round trips)
    if (booking.tripType === 'Round Trip' && booking.drop_status === 'Pending' && !booking.dropNotificationSent) {
      const message = {
        token: token,
        notification: {
          title: "🔔 Drop Needs Driver",
          body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} for a Drop on ${booking.dropDate || "unknown date"} at ${booking.dropTime || "unknown time"}. A driver needs to be assigned.`,
        },
        data: {
          bookingId: bookingId,
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
        await messaging.send(message);
        console.log(`✅ Drop notification for booking ${bookingId} sent.`);
        
        // Update the booking document to mark notification as sent
        await db.collection("new_bookings").doc(bookingId).update({
          dropNotificationSent: true,
          dropNotificationSentAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Updated booking ${bookingId} to prevent duplicate drop notifications.`);

      } catch (error) {
        console.error(`❌ Error sending drop message for booking ${bookingId}:`, error);
      }
    }
  }
}

main().catch(console.error);
