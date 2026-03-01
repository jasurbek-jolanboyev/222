importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Siz yuborgan ma'lumotlar:
firebase.initializeApp({
  apiKey: "AIzaSyAiBJfc2StqTkkPUBeK5cBZvrw0OIUqVYY",
  authDomain: "safechat-7f27d.firebaseapp.com",
  projectId: "safechat-7f27d",
  storageBucket: "safechat-7f27d.firebasestorage.app",
  messagingSenderId: "884836591001",
  appId: "1:884836591001:web:d59ef7bd8842204c685f08",
  measurementId: "G-DWLJSTPTKY"
});

const messaging = firebase.messaging();

// Orqa fonda xabar kelganda ishlashi uchun
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Orqa fonda xabar keldi: ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // Bu yerda ilovangiz ikonkasi bo'lishi kerak
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});