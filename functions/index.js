const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifyManagerOnBooking = functions
  .region("us-central1")
  .firestore
  .document("bookings/{bookingId}")
  .onCreate((snap, context) => {
    const booking = snap.data();

    return admin.firestore().collection("managers").doc("manager").get()
      .then(managerDoc => {
        if (!managerDoc.exists || !managerDoc.data().fcmToken) {
          console.log("No FCM token found.");
          return null;
        }

        const fcmToken = managerDoc.data().fcmToken;

        const message = {
          token: fcmToken,
          notification: {
            title: `New Booking: ${booking.eventName}`,
            body: `Pickup at ${booking.pickupLocation} at ${booking.pickupTime}`,
          },
          data: {
            bookingId: context.params.bookingId,
            status: booking.status || "Pending",
          },
        };

        return admin.messaging().send(message);
      })
      .then(() => {
        console.log("Notification sent.");
        return null;
      })
      .catch(error => {
        console.error("Error sending FCM:", error);
        return null;
      });
  });
