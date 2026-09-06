import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapControllerService {
  final MapController mapController;

  MapControllerService(this.mapController);

  void focusOnPoint(
    LatLng point, {
    double zoom = 18.2,
  }) {
    mapController.move(point, zoom);
  }

  void zoomIn({
    double maxZoom = 20.0,
  }) {
    final z = mapController.camera.zoom;
    mapController.move(
      mapController.camera.center,
      z + 0.6 > maxZoom ? maxZoom : z + 0.6,
    );
  }

  void zoomOut({
    double minZoom = 16.0,
  }) {
    final z = mapController.camera.zoom;
    mapController.move(
      mapController.camera.center,
      z - 0.6 < minZoom ? minZoom : z - 0.6,
    );
  }
}
