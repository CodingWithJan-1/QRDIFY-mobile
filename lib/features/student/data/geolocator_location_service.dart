import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_location_service.dart';

class GeolocatorLocationService implements DeviceLocationService {
  static const _targetAccuracyMeters = 20.0;
  static const _minimumAcquisitionTime = Duration(seconds: 8);
  static const _acquisitionTimeout = Duration(seconds: 25);
  StreamSubscription<Position>? _backgroundSubscription;

  @override
  Future<void> startBackgroundTracking(Duration interval) async {
    if (_backgroundSubscription != null) return;

    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: interval,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'QRDify safety monitoring',
              notificationText: 'Checking the campus boundary on this phone',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          );

    _backgroundSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((_) {}, onError: (_) {});
  }

  @override
  Future<void> stopBackgroundTracking() async {
    await _backgroundSubscription?.cancel();
    _backgroundSubscription = null;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );

    Position? bestPosition;
    final result = Completer<Position>();
    StreamSubscription<Position>? subscription;
    var minimumWaitFinished = false;

    void accept(Position position) {
      final currentBest = bestPosition;
      if (currentBest == null || position.accuracy < currentBest.accuracy) {
        bestPosition = position;
      }
      if (minimumWaitFinished &&
          position.accuracy <= _targetAccuracyMeters &&
          !result.isCompleted) {
        result.complete(position);
      }
    }

    subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          accept,
          onError: (Object error, StackTrace stackTrace) {
            if (result.isCompleted) return;
            final fallback = bestPosition;
            if (fallback != null) {
              result.complete(fallback);
            } else {
              result.completeError(error, stackTrace);
            }
          },
        );

    final minimumWait = Timer(_minimumAcquisitionTime, () {
      minimumWaitFinished = true;
      final best = bestPosition;
      if (best != null &&
          best.accuracy <= _targetAccuracyMeters &&
          !result.isCompleted) {
        result.complete(best);
      }
    });

    final timeout = Timer(_acquisitionTimeout, () {
      if (result.isCompleted) return;
      final fallback = bestPosition;
      if (fallback != null) {
        result.complete(fallback);
      } else {
        result.completeError(TimeoutException('No location fix was received.'));
      }
    });

    late final Position position;
    try {
      position = await result.future;
    } finally {
      minimumWait.cancel();
      timeout.cancel();
      await subscription.cancel();
    }

    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      recordedAt: position.timestamp,
    );
  }

  DeviceLocationPermission _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.denied => DeviceLocationPermission.denied,
      LocationPermission.deniedForever =>
        DeviceLocationPermission.deniedForever,
      LocationPermission.whileInUse => DeviceLocationPermission.whileInUse,
      LocationPermission.always => DeviceLocationPermission.always,
      LocationPermission.unableToDetermine => DeviceLocationPermission.denied,
    };
  }
}
