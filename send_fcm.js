const admin = require("firebase-admin");
const fs = require("fs");

// Load Firebase credentials
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function main() {
  console.log("🔍 Checking for bookings where driverId is not assigned...");

  const snapshot = await db.collection("Bookings").get();
  console.log(snapshot.docs);

  // Filter documents with missing or empty driverId
  const bookingsWithoutDriver = snapshot.docs.filter(doc => {
    const data = doc.data();
    return !data.driverId; // catches undefined, null, empty string
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
        body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} on ${booking.pickupDate} at ${booking.pickupTime}. No driver assigned yet.`,
      },
      token: token,
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
