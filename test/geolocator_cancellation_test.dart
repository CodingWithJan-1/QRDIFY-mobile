import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/features/student/data/geolocator_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Stop cancels an in-progress GPS acquisition and its timers', () async {
    var cancelled = false;
    final positions = StreamController<Position>(
      onCancel: () => cancelled = true,
    );
    final service = GeolocatorLocationService(
      positionStream: (_) => positions.stream,
    );
    final acquisition = service.getCurrentLocation();
    final rejection = expectLater(
      acquisition,
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'location_cancelled',
        ),
      ),
    );
    await service.stopBackgroundTracking();
    await rejection;
    expect(cancelled, isTrue);
    await positions.close();
  });

  test('denied notification permission prevents the foreground stream from starting', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('online.qridify.twces/security');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    var streams = 0;
    final service = GeolocatorLocationService(
      positionStream: (_) {
        streams++;
        return const Stream<Position>.empty();
      },
    );
    try {
      await expectLater(
        service.startBackgroundTracking(const Duration(minutes: 15)),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'tracking_notification_required',
          ),
        ),
      );
      expect(streams, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test('a suppressed notification blocks the next GPS acquisition', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('online.qridify.twces/security');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'requestTrackingNotifications',
    );
    var streams = 0;
    final positions = StreamController<Position>.broadcast();
    final service = GeolocatorLocationService(
      positionStream: (_) {
        streams++;
        return positions.stream;
      },
    );
    try {
      await service.startBackgroundTracking(const Duration(minutes: 15));
      await expectLater(
        service.getCurrentLocation(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'tracking_notification_required',
          ),
        ),
      );
      expect(streams, 1); // Background only; no new acquisition stream.
    } finally {
      await service.stopBackgroundTracking();
      await positions.close();
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}
