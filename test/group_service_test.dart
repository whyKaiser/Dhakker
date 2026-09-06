// Tests for GroupService — the client half of the family-location feature.
//
// This service decides which group a pilgrim is placed into and what is
// written on their membership document. Firestore rules enforce the security
// boundary (see test_firestore_rules/rules.test.mjs, which re-enacts the
// full attack), but the rules can only enforce what the client actually
// sends: the join code has to reach the membership document, or every join
// is refused. These tests pin that contract down, plus the code-resolution
// path that replaced the old enumerate-and-query lookup.
//
// The service had no test coverage at all before this.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/services/group_service.dart';

/// GroupService with the two auth seams driven from the test, so the whole
/// join/create path runs for real against a fake Firestore.
class TestGroupService extends GroupService {
  TestGroupService(FirebaseFirestore db, this._uid, {String name = ''})
      : _name = name,
        super(db: db);

  final String _uid;
  final String _name;

  @override
  String get currentUid => _uid;

  @override
  String get currentDisplayName => _name;
}

const owner = 'owner-uid';
const stranger = 'stranger-uid';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<Map<String, dynamic>?> memberDoc(String groupId, String uid) async {
    final snap = await db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(uid)
        .get();
    return snap.data();
  }

  group('createGroup', () {
    test('writes the group, claims the code, and joins the owner', () async {
      final service = TestGroupService(db, owner, name: 'الأب');
      final res = await service.createGroup('عائلتي');

      final groupSnap = await db.collection('groups').doc(res.groupId).get();
      expect(groupSnap.data()?['name'], 'عائلتي');
      expect(groupSnap.data()?['ownerId'], owner);
      expect(groupSnap.data()?['code'], res.code);

      // The pointer document is what makes the code resolvable without
      // listing the groups collection.
      final pointer = await db.collection('group_codes').doc(res.code).get();
      expect(pointer.exists, isTrue);
      expect(pointer.data()?['groupId'], res.groupId);
      expect(pointer.data()?['ownerId'], owner);
    });

    test('the owner membership carries the join code the rules check',
        () async {
      // Without this field every membership write is refused by the rules,
      // so the owner would be locked out of the group they just made.
      final service = TestGroupService(db, owner, name: 'الأب');
      final res = await service.createGroup('عائلتي');

      final member = await memberDoc(res.groupId, owner);
      expect(member?['joinCode'], res.code);
      expect(member?['name'], 'الأب');
    });

    test('generates a code in the readable HAJJ-NNNN shape', () async {
      final res = await TestGroupService(db, owner).createGroup('م');
      expect(res.code, matches(RegExp(r'^HAJJ-\d{4,5}$')));
    });

    test('does not reuse a code already claimed', () async {
      // Exhaust the four-digit space so the collision path is forced rather
      // than waited for: every four-digit code is taken, so the generator
      // must fall through to the five-digit fallback.
      for (var n = 1000; n <= 9999; n++) {
        await db.collection('group_codes').doc('HAJJ-$n').set({'groupId': 'x'});
      }
      final res = await TestGroupService(db, owner).createGroup('م');
      expect(res.code, matches(RegExp(r'^HAJJ-\d{5}$')));
    });

    test('falls back to the profile name when the account has none', () async {
      await db.collection('users').doc(owner).set({'fullName': 'اسم الملف'});
      final res = await TestGroupService(db, owner).createGroup('م');
      expect((await memberDoc(res.groupId, owner))?['name'], 'اسم الملف');
    });

    test('refuses when nobody is signed in', () async {
      expect(() => TestGroupService(db, '').createGroup('م'), throwsException);
    });
  });

  group('joinByCode', () {
    Future<String> seedGroup({String code = 'HAJJ-4821'}) async {
      await db.collection('groups').doc('g1').set({
        'name': 'عائلتي',
        'code': code,
        'ownerId': owner,
      });
      await db
          .collection('group_codes')
          .doc(code)
          .set({'groupId': 'g1', 'ownerId': owner});
      return 'g1';
    }

    test('resolves a known code and writes it onto the membership', () async {
      await seedGroup();
      final service = TestGroupService(db, stranger, name: 'قريب');
      final groupId = await service.joinByCode('HAJJ-4821');

      expect(groupId, 'g1');
      final member = await memberDoc('g1', stranger);
      expect(member?['joinCode'], 'HAJJ-4821',
          reason: 'the rules match this against the group code');
      expect(member?['name'], 'قريب');
    });

    test('normalizes case and surrounding whitespace', () async {
      await seedGroup();
      final id =
          await TestGroupService(db, stranger).joinByCode('  hajj-4821 ');
      expect(id, 'g1');
      expect((await memberDoc('g1', stranger))?['joinCode'], 'HAJJ-4821');
    });

    test('an unknown code joins nothing at all', () async {
      await seedGroup();
      final service = TestGroupService(db, stranger);
      await expectLater(service.joinByCode('HAJJ-0000'), throwsException);

      expect(await memberDoc('g1', stranger), isNull);
      final me = await db.collection('users').doc(stranger).get();
      expect(me.data()?['groupId'], isNull);
    });

    test('an empty or blank code is refused without a lookup', () async {
      await seedGroup();
      for (final code in ['', '   ']) {
        await expectLater(
            TestGroupService(db, stranger).joinByCode(code), throwsException);
      }
      expect(await memberDoc('g1', stranger), isNull);
    });

    test('a pointer to a missing or malformed group is refused', () async {
      // A dangling pointer must not produce a membership in a group that
      // does not exist, nor a broken groupId on the user record.
      await db.collection('group_codes').doc('HAJJ-9999').set({'groupId': ''});
      await expectLater(TestGroupService(db, stranger).joinByCode('HAJJ-9999'),
          throwsException);
      final me = await db.collection('users').doc(stranger).get();
      expect(me.data()?['groupId'], isNull);
    });

    test('joining records the group on the user document', () async {
      await seedGroup();
      await TestGroupService(db, stranger).joinByCode('HAJJ-4821');
      final me = await db.collection('users').doc(stranger).get();
      expect(me.data()?['groupId'], 'g1');
    });
  });

  group('membership lifecycle', () {
    test('leaving removes the membership and clears the reference', () async {
      final service = TestGroupService(db, owner);
      final res = await service.createGroup('م');

      await service.leaveGroup(res.groupId);

      expect(await memberDoc(res.groupId, owner), isNull);
      final me = await db.collection('users').doc(owner).get();
      expect(me.data()?['groupId'], isNull);
    });

    test('updateMyLocation writes coordinates only for the caller', () async {
      final service = TestGroupService(db, owner);
      final res = await service.createGroup('م');

      await service.updateMyLocation(
          groupId: res.groupId, lat: 21.4225, lng: 39.8262);

      final member = await memberDoc(res.groupId, owner);
      expect(member?['lat'], 21.4225);
      expect(member?['lng'], 39.8262);
      // The merge must not drop the join code, or a later rules evaluation
      // of the document would see a membership with no proof of the code.
      expect(member?['joinCode'], res.code);
    });

    test('streamMembers surfaces members with and without a location',
        () async {
      final service = TestGroupService(db, owner);
      final res = await service.createGroup('م');
      await db
          .collection('groups')
          .doc(res.groupId)
          .collection('members')
          .doc('other')
          .set({'name': 'بلا موقع', 'joinCode': res.code});

      final members = await service.streamMembers(res.groupId).first;
      expect(members.length, 2);
      expect(members.firstWhere((m) => m.uid == 'other').hasLocation, isFalse);
    });
  });

  group('normalizeCode', () {
    test('uppercases and trims', () {
      expect(GroupService.normalizeCode('  hajj-1234  '), 'HAJJ-1234');
      expect(GroupService.normalizeCode('HAJJ-1234'), 'HAJJ-1234');
    });
  });
}
