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

    final ritual = _ritualFor(cubit, currentZone);

    return PilgrimContext(
      consent: true,
      ritual: ritual,
      tawafLapsCompleted: ritual == 'tawaf' ? cubit.roundCount.clamp(0, 7) : null,
      saiLapsCompleted: ritual == 'sai' ? cubit.saiCount.clamp(0, 7) : null,
      // Coarse named zone only (e.g. "Al-Haram") — never raw lat/lng, which
      // never enters this object in the first place.
      zone: currentZone?.zoneId,
    );
  }

  static String? _ritualFor(AppCubit cubit, ZoneModel? zone) {
    final type = zone?.type.toLowerCase() ?? '';
    if (type.contains('tawaf') || cubit.roundCount > 0) return 'tawaf';
    if (type.contains('sai') || cubit.saiCount > 0) return 'sai';
    return 'none';
  }
}
