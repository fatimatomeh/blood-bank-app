const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ── إشعار للمتبرع لما يوصل إشعار جديد ──
exports.notifyDonor = functions.database
  .ref('/Donors/{uid}/notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.val();
    const uid = context.params.uid;

    const tokenSnap = await admin.database()
      .ref(`Donors/${uid}/fcmToken`).get();
    const token = tokenSnap.val();
    if (!token) return null;

    return admin.messaging().send({
      token,
      notification: {
        title: notif.type === 'urgent' ? '🚨 طلب دم عاجل!' : 'VivaLink 🩸',
        body: notif.message || 'إشعار جديد',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'vivalink_high',
          color: '#8b0000',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
  });

// ── إشعار للمستشفى ──
exports.notifyHospital = functions.database
  .ref('/Notifications/{hospitalId}/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.val();
    const hospitalId = context.params.hospitalId;

    // جرب Hospitals أولاً
    const hospTokenSnap = await admin.database()
      .ref(`Hospitals/${hospitalId}/fcmToken`).get();
    let token = hospTokenSnap.val();

    // لو ما لقيت جرب BloodBankStaff
    if (!token) {
      const staffSnap = await admin.database()
        .ref('BloodBankStaff')
        .orderByChild('hospitalId')
        .equalTo(hospitalId)
        .get();

      if (staffSnap.exists()) {
        const staffData = staffSnap.val();
        const firstStaff = Object.values(staffData)[0];
        token = firstStaff.fcmToken;
      }
    }

    if (!token) return null;

    const titleMap = {
      'donor_coming': '🚗 متبرع في الطريق!',
      'new_test': '🔬 فحص دم جديد',
      'blood_transfer_request': '🩸 طلب نقل دم',
      'new_request': '📋 طلب دم جديد',
    };

    return admin.messaging().send({
      token,
      notification: {
        title: titleMap[notif.type] || 'VivaLink 🩸',
        body: notif.message || notif.title || 'إشعار جديد',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'vivalink_high',
          color: '#8b0000',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
  });
