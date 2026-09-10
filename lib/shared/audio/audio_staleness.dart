/// When a stored recitation stops describing the text it was made from.
///
/// ── The gap this closes ───────────────────────────────────────────────────
///
/// A supplication may carry a stored audio file. `DuaPlaybackService` prefers
/// it over device TTS:
///
/// ```dart
/// final hasFile = dua.audioMode == 'file' && dua.audioUrl.trim().isNotEmpty;
/// ```
///
/// Nothing in the project used to connect that file to the TEXT it recites.
/// The admin edit screen carried `audioUrl` forward untouched on every save;
/// the importer lists `audioUrl` among the fields an update must never touch;
/// and the generator skips any record that already has audio. So correcting a
/// verified record's Arabic — the whole reason the review process exists —
/// left the OLD recitation playing, saying words the record no longer holds.
/// `contentHash` was recomputed on save and quietly stopped describing the
/// audio, and nothing compared the two.
///
/// A pilgrim hears the file. They do not read the correction.
///
/// ── The rule ──────────────────────────────────────────────────────────────
///
/// A stored recitation belongs to one exact text. Change the text and the
/// recitation is no longer of it, so it is dropped and playback falls back to
/// TTS until a new file is made. Fail-safe: TTS reads the CURRENT text, which
/// is always honest, where a stale file is confidently wrong.
///
/// This is deliberately not a warning the admin may dismiss. The correction
/// is the point of the edit; leaving the old audio one careless tap away
/// would preserve exactly the failure above.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable identity of a supplication's text.
///
/// sha256 over the UTF-8 bytes of `ar + U+0000 + en` — the construction the
/// admin screen already wrote as `contentHash`, the review ledger records as
/// `reviewedTextHash`, and `scripts/import_source_pack.mjs` computes as
/// `contentHashOf`. Three places must agree on what "the same text" means, so
/// they use one formula rather than three.
///
/// Deliberately NOT Unicode-normalised, matching `contentHashOf`. The
/// importer has a second, NFC-normalising hash (`normalisedTextHash`) used
/// for comparing a payload against a live document, where a pure
/// normalisation difference should not read as an edit. That is a different
/// question from this one: here a changed byte sequence IS a changed stored
/// text, and the audio that recites it can no longer be assumed to match.
String supplicationContentHash(String ar, String en) {
  return sha256.convert(utf8.encode('$ar\u0000$en')).toString();
}

/// Whether the stored recitation no longer describes the text being saved.
///
/// [loadedTextHash] is the hash of the text as it was READ from Firestore —
/// null for a record that carried none, which is treated as "unknown", not as
/// "changed": dropping audio from every legacy record on its first save would
/// destroy recordings nobody asked to replace.
///
/// [replacingAudio] is true when this save uploads a new file. A replacement
/// is the admin recording the new text on purpose, so nothing is stale.
bool storedAudioIsStale({
  required String? loadedTextHash,
  required String currentTextHash,
  required String audioMode,
  required String? audioUrl,
  required bool replacingAudio,
}) {
  if (replacingAudio) return false;
  // Only a stored FILE can be stale. TTS is generated from the current text
  // at playback, so it cannot fall behind it.
  if (audioMode != 'file') return false;
  if (audioUrl == null || audioUrl.trim().isEmpty) return false;
  if (loadedTextHash == null || loadedTextHash.isEmpty) return false;
  return loadedTextHash != currentTextHash;
}
