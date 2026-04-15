import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'permission_service.dart';

class LocationService {
  static final ValueNotifier<Position?> currentPositionNotifier = ValueNotifier<Position?>(null);
  static final ValueNotifier<String?> currentAddressNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  static LocationSettings? _locationSettings;
  static StreamSubscription<Position>? _positionStream;

  static const int _minDistanceFilter = 10; // minimum distance (meters) for location updates
  static const LocationAccuracy _defaultAccuracy = LocationAccuracy.high;

  static Future<void> initialize() async {
    await _setupLocationSettings();
    await getCurrentLocation();
    _startLocationUpdates();
  }

  static Future<void> _setupLocationSettings() async {
    _locationSettings = LocationSettings(
      accuracy: _defaultAccuracy,
      distanceFilter: _minDistanceFilter,
      timeLimit: const Duration(seconds: 5),
    );
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Use the permission status from PermissionService instead of requesting again
      if (!await PermissionService.hasLocationPermission()) {
        throw Exception('Location permissions are not granted');
      }

      isLoadingNotifier.value = true;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPositionNotifier.value = position;

      // Get address from coordinates
      await _getAddressFromCoordinates(position);
      isLoadingNotifier.value = false;

      return currentPositionNotifier.value;
    } catch (e) {
      debugPrint('Error getting location: $e');
      isLoadingNotifier.value = false;
      return null;
    }
  }

  static Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        currentAddressNotifier.value = '${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  static Position? get currentPosition => currentPositionNotifier.value;
  static String? get currentAddress => currentAddressNotifier.value;

  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  static bool isWithinRadius(
    double targetLat,
    double targetLon,
    double currentLat,
    double currentLon,
    double radiusMeters,
  ) {
    double distance = calculateDistance(targetLat, targetLon, currentLat, currentLon);
    return distance <= radiusMeters;
  }

  static String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Clean up any resources used by the LocationService
  static void _startLocationUpdates() {
    _stopLocationUpdates(); // Clear any existing subscription
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (Position position) async {
        currentPositionNotifier.value = position;
        await _getAddressFromCoordinates(position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  static void _stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Call this method when the app is going to background
  static void pauseLocationUpdates() {
    _stopLocationUpdates();
  }

  /// Call this method when the app is coming to foreground
  static void resumeLocationUpdates() {
    _startLocationUpdates();
  }

  /// Clean up resources
  static void dispose() {
    _stopLocationUpdates();
    currentPositionNotifier.dispose();
    currentAddressNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
