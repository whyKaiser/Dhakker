// English is optional on a supplication.
//
// The ministry source is Arabic. Not one of the 85 records in
// `source_packs/moia_mukhtasar_1446_umrah.json` carries a `text.en`, and
// `docs/AUDIO_INVENTORY.md` states the same: "All 59 are `ar` only; no record
// has `text.en`."
//
// Both admin screens used to refuse a save without an English title AND an
// English body. That did not produce translations; it produced a form that
// could not store the project's actual content, and it invited the reviewer
// to type a translation at the keyboard — an invented rendering of a
// religious text, entered under time pressure, with no source behind it.
//
// Arabic stays required. It is the text.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _addScreen =
    'lib/Screens/Admin/Manage Supplications/admin_supplication_add_screen.dart';
const _editScreen =
    'lib/Screens/Admin/Manage Supplications/admin_supplication_edit_screen.dart';

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) throw StateError('missing file: $path');
  return f.readAsStringSync();
}

void main() {
  group('the admin screens do not demand English', () {
    test('neither screen refuses a save for a missing English field', () {
      for (final path in [_addScreen, _editScreen]) {
        final src = _read(path);
        for (final key in [
          'adminSupplicationTitleEnRequired',
          'adminSupplicationTextEnRequired',
        ]) {
          expect(
            src.contains(key),
            isFalse,
            reason: '$path still blocks a save on $key',
          );
        }
      }
    });

    test('Arabic is still required in both screens', () {
      // The other half of the rule. Dropping the English requirement must not
      // drift into accepting a record with no text at all.
      for (final path in [_addScreen, _editScreen]) {
        final src = _read(path);
        for (final key in [
          'adminSupplicationTitleArRequired',
          'adminSupplicationTextArRequired',
        ]) {
          expect(
            src.contains(key),
            isTrue,
            reason: '$path no longer requires $key',
          );
        }
      }
    });

    test('the English fields are still offered, just not compelled', () {
      // Optional is not removed: a record that HAS an approved translation
      // must still be able to carry it.
      for (final path in [_addScreen, _editScreen]) {
        final src = _read(path);
        expect(src.contains('_textEnController'), isTrue, reason: path);
        expect(src.contains('adminSupplicationTextEn'), isTrue, reason: path);
      }
    });

    test('both screens still write the English key, empty when unset', () {
      // The model reads `text.en` with a fallback, but a record written
      // without the key at all would differ in shape from every imported one.
      for (final path in [_addScreen, _editScreen]) {
        final src = _read(path);
        expect(
          src.contains("'en': _textEnController.text.trim()"),
          isTrue,
          reason: '$path no longer stores text.en',
        );
      }
    });
  });

  group('the pack is why', () {
    // Read as data, not scanned as text: an earlier version of this test
    // matched any `"en": "..."` anywhere in the file and failed, because the
    // two fields differ and the sloppy version could not tell them apart.
    // The distinction is the whole justification, so the test has to make it.
    List<Map<String, dynamic>> entries() {
      final pack = jsonDecode(
        _read('source_packs/moia_mukhtasar_1446_umrah.json'),
      ) as Map<String, dynamic>;
      return (pack['entries'] as List).cast<Map<String, dynamic>>();
    }

    String? englishOf(Map<String, dynamic> entry, String field) {
      final map = entry[field];
      if (map is! Map) return null;
      final en = map['en'];
      return (en is String && en.trim().isNotEmpty) ? en : null;
    }

    test('not one record carries an English BODY', () {
      // So requiring `text.en` blocked every real record without exception.
      final withBody =
          entries().where((e) => englishOf(e, 'text') != null).toList();
      expect(
        withBody,
        isEmpty,
        reason: 'the pack now ships English bodies; revisit this decision',
      );
    });

    test('English TITLES exist on some records but not most', () {
      // A weaker but sufficient reason: requiring `title.en` blocked the
      // majority. Stated as a range rather than a fixed count so adding a
      // title does not fail a test that is about the shape, not the tally.
      final all = entries();
      final withTitle = all.where((e) => englishOf(e, 'title') != null).length;
      expect(withTitle, greaterThan(0), reason: 'some titles are translated');
      expect(withTitle, lessThan(all.length),
          reason: 'if every title were translated, requiring one would be '
              'defensible — check whether this decision still holds');
    });
  });
}
