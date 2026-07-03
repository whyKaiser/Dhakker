import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// يستمع للإشعارات الجماعية التي يرسلها الأدمن من Firestore.
/// عند وصول وثيقة جديدة في مجموعة `broadcasts` يعرض إشعاراً محلياً فورياً.
class BroadcastListenerService {
  BroadcastListenerService._();
  static final BroadcastListenerService instance = BroadcastListenerService._();

  static const String _lastSeenKey = 'broadcast_last_seen_ts';

  // نحفظ الاشتراك نفسه (لا الـ Stream) حتى نستطيع إلغاءه فعلياً في stop —
  // بدونه يبقى المستمع حيّاً للأبد وتتكرر الإشعارات عند إعادة البدء.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _started = false;

  Future<void> start({bool isAr = true}) async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenMs = prefs.getInt(_lastSeenKey) ?? 0;
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);

    await _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('broadcasts')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSeen))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snap) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        final msg = (data['message'] ?? '').toString().trim();
        if (msg.isEmpty) continue;

        await NotificationService.instance.showBroadcast(
          title: isAr ? '📢 رسالة من الإدارة' : '📢 Admin Message',
          body: msg,
        );

        // حفّظ الختم الزمني لهذه الوثيقة حتى لا يُعاد إظهارها
        final ts = data['timestamp'];
        if (ts is Timestamp) {
          await prefs.setInt(
            _lastSeenKey,
            ts.toDate().millisecondsSinceEpoch,
          );
        }
      }
    });
  }

  void stop() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
  }
}
