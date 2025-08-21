const admin = require("firebase-admin");
const fs = require("fs");

// Load Firebase credentials
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

const now = new Date();
const twoMinutesAgo = new Date(now.getTime() - 2 * 60 * 1000);

async function main() {
  console.log("Checking for new bookings since:", twoMinutesAgo);

  const snapshot = await db.collection("Bookings")
    .where("timestamp", ">", twoMinutesAgo)
    .get();

  if (snapshot.empty) {
    console.log("No new bookings in the last 2 minutes.");
    return;
  }

  // Get the FCM token of the manager
  const managerDoc = await db.collection("managers").doc("manager").get();
  const managerData = managerDoc.data();

  if (!managerData || !managerData.fcmToken) {
    console.error("No FCM token found for manager.");
    return;
  }

  const token = managerData.fcmToken;

  // Send a notification for each new booking
  for (const doc of snapshot.docs) {
    const booking = doc.data();

    const message = {
      notification: {
        title: "New Booking Received",
        body: `${booking.resourcePerson || "Someone"} booked ${booking.facility || "a vehicle"} on ${booking.pickupDate} at ${booking.pickupTime}`,
      },
      token: token,
    };

    try {
      const response = await messaging.send(message);
      console.log("Notification sent:", response);
    } catch (error) {
      console.error("Error sending message:", error);
    }
  }
}

main().catch(console.error);
