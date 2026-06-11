
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class MapService {
  MapService._();
  static final MapService instance = MapService._();

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GPS service tidak aktif');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permission lokasi ditolak');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permission lokasi ditolak permanen');
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint('Lokasi: ${position.latitude}, ${position.longitude}');
    return position;
  }

  Stream<Position> getLocationStream({
    int intervalMs = 3000,
    double distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
      ),
    );
  }

  double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  double calculateCostByDistance({
    required double distanceMeters,
    required double hargaDasar,
    required double hargaPerKm,
    required double hargaPerKg,
    required double beratKg,
  }) {
    final distanceKm = distanceMeters / 1000;
    return hargaDasar + (distanceKm * hargaPerKm) + (beratKg * hargaPerKg);
  }
}
