import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  GroupService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// يولّد كود انضمام قصير سهل القراءة مثل: HAJJ-4821
  String _generateCode() {
    final n = Random().nextInt(9000) + 1000; // 1000..9999
    return 'HAJJ-$n';
  }

  /// ينشئ مجموعة جديدة ويُضيف المنشئ كعضو، ويعيد (groupId, code).
  Future<({String groupId, String code})> createGroup(String name) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('غير مسجّل الدخول');

    final code = _generateCode();
    final ref = _groups.doc();
    await ref.set({
      'name': name.trim().isEmpty ? 'مجموعتي' : name.trim(),
      'code': code,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _addSelfAsMember(ref.id);
    await _setMyGroupId(ref.id);
    return (groupId: ref.id, code: code);
  }

  /// ينضم لمجموعة عبر الكود. يرمي استثناءً إذا لم يوجد الكود.
  Future<String> joinByCode(String code) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('غير مسجّل الدخول');

    final normalized = code.trim().toUpperCase();
    final query =
        await _groups.where('code', isEqualTo: normalized).limit(1).get();
    if (query.docs.isEmpty) {
      throw Exception('لا توجد مجموعة بهذا الكود');
    }

    final groupId = query.docs.first.id;
    await _addSelfAsMember(groupId);
    await _setMyGroupId(groupId);
    return groupId;
  }

  Future<void> _addSelfAsMember(String groupId) async {
    final uid = _uid;
    String name = _auth.currentUser?.displayName ?? '';
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
