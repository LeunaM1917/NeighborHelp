/* Firebase Hosting supplies the public app configuration at this reserved URL.
 * No credentials or API keys are embedded in this file. */
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');
importScripts('/__/firebase/init.js');
const messaging = firebase.messaging();
messaging.onBackgroundMessage(payload => {
  // Notification payloads are already displayed by FCM; avoid showing a duplicate.
  if (payload.notification) return;
  return self.registration.showNotification('NeighborHelp', {
    body: payload.data?.message || 'You have a new update.',
    tag: payload.data?.notificationId,
  });
});
