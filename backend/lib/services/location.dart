import 'dart:math';

import '../models.dart';

class _City {
  const _City(this.name, this.latitude, this.longitude, this.radiusKm);
  final String name;
  final double latitude;
  final double longitude;
  final double radiusKm;
}

const List<_City> _cities = <_City>[
  _City('Brooklyn', 40.6782, -73.9442, 12),
  _City('Manhattan', 40.7831, -73.9712, 10),
  _City('Austin', 30.2672, -97.7431, 35),
  _City('Chicago', 41.8781, -87.6298, 35),
];

/// Maps coordinates to the nearest supported city within its radius, otherwise
/// "Other". Never defaults to a real city for unknown places.
String locationFromCoordinates(double latitude, double longitude) {
  String best = otherLocation;
  var bestDistance = double.infinity;
  for (final city in _cities) {
    final distance = _haversineKm(latitude, longitude, city.latitude, city.longitude);
    if (distance <= city.radiusKm && distance < bestDistance) {
      best = city.name;
      bestDistance = distance;
    }
  }
  return best;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double rad(double degrees) => degrees * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * earthRadiusKm * asin(min(1.0, sqrt(a)));
}
