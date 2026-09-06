import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// فرد في مجموعة الحاج: معرّفه واسمه وآخر موقع شاركه (قد يكون null إن لم يشارك).
class GroupMember {
  final String uid;
  final String name;
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;

  const GroupMember({
    required this.uid,
    required this.name,
    this.lat,
    this.lng,
    this.updatedAt,
  });

  factory GroupMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['updatedAt'];
    return GroupMember(
      uid: doc.id,
      name: (d['name'] ?? '').toString(),
      lat: (d['lat'] is num) ? (d['lat'] as num).toDouble() : null,
      lng: (d['lng'] is num) ? (d['lng'] as num).toDouble() : null,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  bool get hasLocation => lat != null && lng != null;
}

/// خدمة المجموعات: إنشاء/انضمام/مغادرة، بثّ أفراد المجموعة، وتحديث موقع الحاج.
///
/// الخصوصية: لا يُكتب موقع الحاج إلا عند تفعيله المشاركة صراحةً (يتحكّم به
/// المتصل عبر [updateMyLocation]). مشاركة الموقع اختيارية بالكامل.
///
/// ملاحظة: تحتاج قواعد أمان Firestore تسمح لأعضاء المجموعة بقراءة/كتابة
/// مستندات `groups/{id}` و `groups/{id}/members/{uid}`.
class GroupService {
  // Both plugin singletons wire platform channels the moment they are
  // touched, so resolving them in the initializer would make this service
  // unconstructible off-device even when every seam below is overridden.
  // `late final` defers that to first real use — on a device nothing
  // changes; in a test that supplies a fake db and overrides the auth
  // seams, FirebaseAuth.instance is never reached at all.
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  late final FirebaseFirestore _db = _dbOverride ?? FirebaseFirestore.instance;
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;

  GroupService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  // ── auth seams ──────────────────────────────────────────────────────────
  //
  // The only two places this service reads the signed-in identity. They are
  // separated out so the join/create logic — which decides who may see a
  // family's live location — can be exercised without a real FirebaseAuth
  // instance. Everything else runs for real against a fake Firestore.

  @protected
  @visibleForTesting
  String get currentUid => _auth.currentUser?.uid ?? '';

  @protected
  @visibleForTesting
  String get currentDisplayName => _auth.currentUser?.displayName ?? '';

  String get _uid => currentUid;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// مؤشّرات الكود → المجموعة. معرّف كل وثيقة هو الكود نفسه، فيُحلّ الكود
  /// بـ`get` مباشر لا باستعلام. هذا ما يسمح بمنع سرد `groups` كليًّا:
  /// من لا يعرف الكود لا يملك طريقة لاكتشافه.
  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('group_codes');

  /// يطبّع الكود إلى الصيغة المخزَّنة. الكود معرّف وثيقة، فلا يحتمل فراغًا
  /// ولا اختلاف حالة أحرف ولا شرطة مائلة (وهي محظورة في معرّفات Firestore).
  static String normalizeCode(String code) => code.trim().toUpperCase();

  /// يولّد كود انضمام قصير سهل القراءة مثل HAJJ-4821 مع ضمان عدم تصادمه
  /// مع كود مسجَّل (فضاء الأكواد 9000 فقط، والتصادم يعني انضمام حاج
  /// لمجموعة غريبة). بعد عدة تصادمات نوسّع لخمس خانات كخطة أخيرة.
  ///
  /// الفحص يجري على `group_codes` لا على `groups`: هي السجل الحاسم للتفرّد
  /// (كود مسجَّل هناك لا يُعاد تسجيله)، وهي المقروءة بـ`get` دون سرد.
  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = 'HAJJ-${Random().nextInt(9000) + 1000}'; // 1000..9999
      final existing = await _codes.doc(code).get();
      if (!existing.exists) return code;
    }
    return 'HAJJ-${Random().nextInt(90000) + 10000}'; // 10000..99999
  }

  /// ينشئ مجموعة جديدة ويُضيف المنشئ كعضو، ويعيد (groupId, code).
  Future<({String groupId, String code})> createGroup(String name) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('غير مسجّل الدخول');

    final code = await _generateUniqueCode();
    final ref = _groups.doc();
    await ref.set({
      'name': name.trim().isEmpty ? 'مجموعتي' : name.trim(),
      'code': code,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // المؤشّر يُكتب بعد المجموعة: لو فشلت كتابة المجموعة لا يبقى كود
    // معلّق يشير إلى لا شيء. والقواعد تمنع تعديله لاحقًا، فلا يُخطَف.
    await _codes.doc(code).set({
      'groupId': ref.id,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _addSelfAsMember(ref.id, code);
    await _setMyGroupId(ref.id);
    return (groupId: ref.id, code: code);
  }

  /// ينضم لمجموعة عبر الكود. يرمي استثناءً إذا لم يوجد الكود.
  Future<String> joinByCode(String code) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('غير مسجّل الدخول');

    final normalized = normalizeCode(code);
    if (normalized.isEmpty) throw Exception('لا توجد مجموعة بهذا الكود');

    final pointer = await _codes.doc(normalized).get();
    final groupId = pointer.data()?['groupId'];
    if (!pointer.exists || groupId is! String || groupId.isEmpty) {
      throw Exception('لا توجد مجموعة بهذا الكود');
    }

    // الكود يُمرَّر إلى وثيقة العضوية: القواعد تطابقه بكود المجموعة، فلا
    // ينضم أحد إلى مجموعة لا يعرف كودها.
    await _addSelfAsMember(groupId, normalized);
    await _setMyGroupId(groupId);
    return groupId;
  }

  Future<void> _addSelfAsMember(String groupId, String joinCode) async {
    final uid = _uid;
    String name = currentDisplayName;
    if (name.trim().isEmpty) {
      try {
        final prof = await _db.collection('users').doc(uid).get();
        final data = prof.data();
        name = (data?['fullName'] ?? data?['name'] ?? 'حاج').toString();
      } catch (_) {
        name = 'حاج';
      }
    }
    await _groups.doc(groupId).collection('members').doc(uid).set({
      'name': name,
      'joinCode': joinCode,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setMyGroupId(String groupId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'groupId': groupId}, SetOptions(merge: true));
  }

  /// يغادر المجموعة الحالية: يحذف عضويته ويمسح groupId من حسابه.
  Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await _groups.doc(groupId).collection('members').doc(uid).delete();
    } catch (_) {/* نتابع لمسح المرجع محلياً */}
    await _db
        .collection('users')
        .doc(uid)
        .set({'groupId': FieldValue.delete()}, SetOptions(merge: true));
  }

  /// يعيد معرّف مجموعة الحاج الحالية (أو null).
  Future<String?> myGroupId() async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final gid = doc.data()?['groupId'];
      return (gid is String && gid.isNotEmpty) ? gid : null;
    } catch (_) {
      return null;
    }
  }

  /// يجلب اسم وكود المجموعة (للعرض ومشاركة الكود/الـ QR).
  Future<({String name, String code})?> groupInfo(String groupId) async {
    try {
      final doc = await _groups.doc(groupId).get();
      final d = doc.data();
      if (d == null) return null;
      return (
        name: (d['name'] ?? 'مجموعتي').toString(),
        code: (d['code'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// بثّ أفراد المجموعة لحظياً (للخريطة وقائمة المسافات).
  Stream<List<GroupMember>> streamMembers(String groupId) {
    return _groups
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map(GroupMember.fromDoc).toList());
  }

  /// يحدّث موقع الحاج في مجموعته. يُستدعى فقط عند موافقته على المشاركة.
  Future<void> updateMyLocation({
    required String groupId,
    required double lat,
    required double lng,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await _groups.doc(groupId).collection('members').doc(uid).set({
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* تجاهل أخطاء الكتابة العابرة (بلا نت مثلاً) */}
  }
}
