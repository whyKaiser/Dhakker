import '../Screens/Piligram/Home/controllers/home_dua_controller.dart';
import '../Screens/Piligram/Home/models/zone_model.dart';
import '../bloc/cubit.dart';
import 'assistant_service.dart';

/// Builds a [PilgrimContext] snapshot from the app's EXISTING sources of
/// truth — [AppCubit] (Tawaf `roundCount`, Sa'i `saiCount`) and the
/// currently-detected [ZoneModel] (from `HomeDuaController.currentZone`).
///
/// This never creates a new counter/stream: it only reads values that
/// already exist elsewhere in the app, and only returns a non-empty
/// context when [consent] is true — matching the Worker's own consent gate
/// in `assistant-proxy/worker.js`.
class PilgrimContextBuilder {
  const PilgrimContextBuilder._();

  static PilgrimContext build({
    required bool consent,
    required AppCubit cubit,
    ZoneModel? currentZone,
  }) {
    if (!consent) return PilgrimContext.none;

    // Reuse HomeDuaController.currentZone via its static, in-memory mirror
    // (HomeDuaController.lastKnownZone) when the caller doesn't pass one
    // explicitly — never a second GPS/zone stream, just the same coarse
    // value that controller already computed.
    final zone = currentZone ?? HomeDuaController.lastKnownZone;

    final ritual = _ritualFor(cubit);

    return PilgrimContext(
      consent: true,
      ritual: ritual,
      // Only ever attached when that specific ritual is verified ACTIVE
      // right now (real-time GPS-proximity signal), never merely because a
      // lap counter is non-zero — a counter stays non-zero for hours after
      // the ritual actually finished and must not be used to infer it.
      tawafLapsCompleted:
          ritual == 'tawaf' ? cubit.roundCount.clamp(0, 7) : null,
      saiLapsCompleted: ritual == 'sai' ? cubit.saiCount.clamp(0, 7) : null,
      // Coarse named zone only (e.g. "Al-Haram") — never raw lat/lng, which
      // never enters this object in the first place.
      zone: zone?.zoneId,
    );
  }

  /// Determines the CURRENTLY active ritual using real-time state only.
  /// Deliberately does NOT infer "tawaf"/"sai" merely because
  /// `roundCount`/`saiCount` > 0 — those counters remain non-zero long after
  /// the ritual has actually ended and would mislabel a stale session as
  /// in-progress. If no reliable active-session signal is available, this
  /// reports 'none' rather than guessing.
  static String _ritualFor(AppCubit cubit) {
    if (cubit.isTawafActive) return 'tawaf';
    if (cubit.isSaiActive) return 'sai';
    return 'none';
  }
}
