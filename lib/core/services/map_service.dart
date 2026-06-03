// lib/features/maps/map_service.dart
// Service GPS & Maps menggunakan geolocator + flutter_map (OpenStreetMap)
// Berdasarkan materi: Implementasi Map & GPS di Flutter

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class MapService {
  // ── Singleton ──────────────────────────────────────────────────
  MapService._();
  static final MapService instance = MapService._();

  // ── Request Permission & Get Current Location ──────────────────
  // Slide 9 materi: Request permission → Aktifkan GPS → Ambil posisi
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cek apakah GPS service aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GPS service tidak aktif');
      return null;
    }

    // 2. Cek & minta permission
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

    // 3. Ambil posisi terkini (latitude & longitude)
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint('Lokasi: ${position.latitude}, ${position.longitude}');
    return position;
  }

  // ── Real-time Stream Lokasi (untuk tracking seperti Gojek) ─────
  // Best practice dari materi slide 12: gunakan interval & distance filter
  Stream<Position> getLocationStream({
    int intervalMs = 3000,       // Update setiap 3 detik
    double distanceFilter = 10,  // Minimum 10 meter bergerak
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        // interval update — menghemat baterai sesuai best practice materi
      ),
    );
  }

  // ── Hitung jarak antara 2 titik (dalam meter) ──────────────────
  double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // ── Hitung estimasi biaya berdasarkan jarak real ───────────────
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
