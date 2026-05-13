import 'package:geolocator/geolocator.dart';

class LiveLocationException implements Exception {
  const LiveLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LiveCoordinates {
  const LiveCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class LiveLocationService {
  const LiveLocationService();

  Future<LiveCoordinates> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LiveLocationException('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const LiveLocationException('Location permission was not granted.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );

    return LiveCoordinates(latitude: position.latitude, longitude: position.longitude);
  }
}
