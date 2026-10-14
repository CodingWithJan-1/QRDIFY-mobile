import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_location_service.dart';
import '../../../core/network/api_exception.dart';

class GeolocatorLocationService implements DeviceLocationService {
  GeolocatorLocationService({
    Stream<Position> Function(LocationSettings)? positionStream,
  }) : _positionStream =
           positionStream ??
           ((settings) =>
               Geolocator.getPositionStream(locationSettings: settings));

  final Stream<Position> Function(LocationSettings) _positionStream;
  final Map<Completer<Position>, StreamSubscription<Position>> _activeCaptures =
      {};
  int _generation = 0;
  static const _targetAccuracyMeters = 20.0;
  static const _minimumAcquisitionTime = Duration(seconds: 8);
  static const _acquisitionTimeout = Duration(seconds: 25);
  StreamSubscription<Position>? _backgroundSubscription;

  @override
  Future<void> startBackgroundTracking(Duration interval) async {
    if (_backgroundSubscription != null) return;
    final generation = _generation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final allowed = await const MethodChannel('online.qridify.twces/security')
          .invokeMethod<bool>('requestTrackingNotifications');
      if (allowed != true) {
        throw const ApiException(
          message: 'Enable QRDify notifications in phone settings before starting location sharing.',
          code: 'tracking_notification_required',
        );
      }
    }
    if (generation != _generation) return;

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

    _backgroundSubscription = _positionStream(settings)
        .listen((_) {}, onError: (_) {});
  }

  @override
  Future<void> stopBackgroundTracking() async {
    _generation++;
    final cancellations = <Future<void>>[];
    final background = _backgroundSubscription;
    _backgroundSubscription = null;
    if (background != null) cancellations.add(background.cancel());
    for (final capture in _activeCaptures.entries.toList()) {
      if (!capture.key.isCompleted) {
        capture.key.completeError(
          const ApiException(
            message: 'Location sharing stopped.',
            code: 'location_cancelled',
          ),
        );
      }
      cancellations.add(capture.value.cancel());
    }
    _activeCaptures.clear();
    await Future.wait(cancellations);
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
    if (defaultTargetPlatform == TargetPlatform.android &&
        _backgroundSubscription != null) {
      final visible = await const MethodChannel('online.qridify.twces/security')
          .invokeMethod<bool>('trackingNotificationsEnabled');
      if (visible != true) {
        throw const ApiException(
          message: 'Enable the QRDify location notification in phone settings. Sharing has stopped.',
          code: 'tracking_notification_required',
        );
      }
    }
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

    subscription = _positionStream(settings).listen(
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
    _activeCaptures[result] = subscription;

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
      _activeCaptures.remove(result);
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
