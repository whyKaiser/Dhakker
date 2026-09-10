// A stored recitation belongs to one exact text.
//
// Before this, correcting a verified record's Arabic left the OLD recording
// playing: the admin screen carried `audioUrl` forward untouched, the
// importer lists it among the fields an update must never modify, and the
// generator skips any record that already has audio. Three writers, none of
// which would ever replace it. `contentHash` was recomputed and quietly
// stopped describing the audio, and nothing compared the two.
//
// A pilgrim hears the file. They do not read the correction.

import 'package:dhakker/shared/audio/audio_staleness.dart';
import 'package:flutter_test/flutter_test.dart';

/// The arguments of a record that is stale in every respect, for mutation by
/// each test.
bool stale({
  String? loadedTextHash = 'OLD',
  String currentTextHash = 'NEW',
  String audioMode = 'file',
  String? audioUrl = 'https://example.test/a.mp3',
  bool replacingAudio = false,
}) {
  return storedAudioIsStale(
    loadedTextHash: loadedTextHash,
    currentTextHash: currentTextHash,
    audioMode: audioMode,
    audioUrl: audioUrl,
    replacingAudio: replacingAudio,
  );
}

void main() {
  group('the content hash', () {
    test('is stable and depends on both bodies', () {
      expect(
        supplicationContentHash('ألف', 'alif'),
        supplicationContentHash('ألف', 'alif'),
      );
      expect(
        supplicationContentHash('ألف', 'alif'),
        isNot(supplicationContentHash('باء', 'alif')),
      );
      expect(
        supplicationContentHash('ألف', 'alif'),
        isNot(supplicationContentHash('ألف', 'baa')),
      );
    });

    test('is a sha256 hex digest', () {
      final h = supplicationContentHash('x', 'y');
      expect(h.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
    });

    test('the separator keeps a moved boundary from colliding', () {
      // Without a separator, ('ab','c') and ('a','bc') would hash the same —
      // two different records reading as one text, and one file serving both.
      expect(
        supplicationContentHash('ab', 'c'),
        isNot(supplicationContentHash('a', 'bc')),
      );
    });

    test('matches the formula the ledger and the importer use', () {
      // Digests computed OUTSIDE this code, so the test pins the formula
      // rather than restating it. Both are sha256 over ar + U+0000 + en —
      // the same construction as `contentHashOf` in
      // scripts/import_source_pack.mjs and `reviewedTextHash` in the ledger.
      // A separator change, an encoding change, or a dropped field breaks
      // agreement between the three, and breaks these two lines first.
      expect(
        supplicationContentHash('x', 'y'),
        'ce3890a816f5237a17aa7e1436113bbac398dfe216cf965537cd035bdbad900a',
      );
      expect(
        supplicationContentHash('', ''),
        '6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d',
      );
    });
  });

  group('when a stored recitation goes stale', () {
    test('a changed text with an unreplaced file is stale', () {
      // THE case this file exists for.
      expect(stale(), isTrue);
    });

    test('an unchanged text is never stale', () {
      expect(stale(loadedTextHash: 'SAME', currentTextHash: 'SAME'), isFalse);
    });

    test('uploading a replacement is not staleness', () {
      // The admin recording the new text on purpose. Dropping the file they
      // just chose would discard the very thing they came to do.
      expect(stale(replacingAudio: true), isFalse);
    });

    test('TTS cannot fall behind the text', () {
      // It is generated from the current text at playback time.
      expect(stale(audioMode: 'tts'), isFalse);
      expect(stale(audioMode: ''), isFalse);
    });

    test('a record with no file has nothing to go stale', () {
      for (final url in [null, '', '   ']) {
        expect(stale(audioUrl: url), isFalse, reason: 'url: "$url"');
      }
    });

    test('an unknown previous text is not treated as a change', () {
      // Dropping audio from every record whose text could not be read would
      // destroy recordings nobody asked to replace.
      expect(stale(loadedTextHash: null), isFalse);
      expect(stale(loadedTextHash: ''), isFalse);
    });

    test('a file whose mode says tts is left alone', () {
      // audioMode 'tts' with a URL still present is an inconsistency for an
      // admin to resolve in the console, not for a save to silently clean up.
      expect(stale(audioMode: 'tts', audioUrl: 'https://x/y.mp3'), isFalse);
    });

    test('every disqualifier alone is enough', () {
      // Each condition is independent: no combination of the others can make
      // a non-stale case read as stale.
      expect(stale(replacingAudio: true, audioMode: 'tts'), isFalse);
      expect(stale(loadedTextHash: null, audioUrl: null), isFalse);
    });

    test('real hashes, not sentinels, drive the decision', () {
      // The strings above are stand-ins; this runs the actual formula, so a
      // change to the hash that broke agreement would show up here.
      final before = supplicationContentHash('اللهم لبيك', '');
      final after = supplicationContentHash('اللهم لبيك ولا شريك لك', '');
      expect(
        storedAudioIsStale(
          loadedTextHash: before,
          currentTextHash: after,
          audioMode: 'file',
          audioUrl: 'https://x/y.mp3',
          replacingAudio: false,
        ),
        isTrue,
      );
      expect(
        storedAudioIsStale(
          loadedTextHash: before,
          currentTextHash: before,
          audioMode: 'file',
          audioUrl: 'https://x/y.mp3',
          replacingAudio: false,
        ),
        isFalse,
      );
    });

    test('a whitespace-only edit still counts as a change', () {
      // The screen hashes the trimmed text on save and the untrimmed text on
      // load, so a record stored with stray whitespace reads as changed on
      // its first save. Dropping the audio there is the safe direction: the
      // stored text really did change, and TTS reads whatever is stored.
      expect(
        supplicationContentHash('نص ', ''),
        isNot(supplicationContentHash('نص', '')),
      );
    });
  });
}
