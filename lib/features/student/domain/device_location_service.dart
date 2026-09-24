class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
}

enum DeviceLocationPermission { denied, deniedForever, whileInUse, always }

abstract interface class DeviceLocationService {
  Future<bool> isServiceEnabled();

  Future<DeviceLocationPermission> checkPermission();

  Future<DeviceLocationPermission> requestPermission();

  Future<DeviceLocation> getCurrentLocation();

  Future<void> startBackgroundTracking(Duration interval);

  Future<void> stopBackgroundTracking();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
