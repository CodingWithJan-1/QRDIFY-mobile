import 'dart:math' as math;

import 'device_location_service.dart';

enum BoundaryState { inside, outside, unknown }

class StudentLocationConsent {
  const StudentLocationConsent({
    required this.enabled,
    required this.policyVersion,
    this.consentedAt,
    this.revokedAt,
  });

  factory StudentLocationConsent.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing location consent data.');
    }
    final policyVersion = data['policy_version']?.toString();
    if (policyVersion == null || policyVersion.isEmpty) {
      throw const FormatException('Missing location consent policy version.');
    }

    return StudentLocationConsent(
      enabled: data['enabled'] == true,
      policyVersion: policyVersion,
      consentedAt: DateTime.tryParse(data['consented_at']?.toString() ?? ''),
      revokedAt: DateTime.tryParse(data['revoked_at']?.toString() ?? ''),
    );
  }

  final bool enabled;
  final String policyVersion;
  final DateTime? consentedAt;
  final DateTime? revokedAt;
}

class GeofencePoint {
  const GeofencePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class StudentGeofencePolicy {
  const StudentGeofencePolicy({
    required this.enabled,
    required this.polygon,
    required this.boundaryBufferMeters,
    required this.maxAccuracyMeters,
    required this.outsideConfirmations,
    required this.insideConfirmations,
    required this.confirmationWindow,
    required this.trackingWindowActive,
    required this.activeBreach,
    this.version,
  });

  final bool enabled;
  final int? version;
  final List<GeofencePoint> polygon;
  final double boundaryBufferMeters;
  final double maxAccuracyMeters;
  final int outsideConfirmations;
  final int insideConfirmations;
  final Duration confirmationWindow;
  final bool trackingWindowActive;
  final bool activeBreach;

  factory StudentGeofencePolicy.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing geofence policy data.');
    }

    final rawPolygon = data['polygon'];
    final polygon = rawPolygon is List
        ? rawPolygon
              .map((point) {
                if (point is! Map<String, dynamic>) {
                  throw const FormatException('Invalid geofence point.');
                }
                final latitude = point['lat'];
                final longitude = point['lng'];
                if (latitude is! num || longitude is! num) {
                  throw const FormatException('Invalid geofence coordinate.');
                }
                return GeofencePoint(
                  latitude: latitude.toDouble(),
                  longitude: longitude.toDouble(),
                );
              })
              .toList(growable: false)
        : const <GeofencePoint>[];

    return StudentGeofencePolicy(
      enabled: data['enabled'] == true,
      version: (data['version'] as num?)?.toInt(),
      polygon: polygon,
      boundaryBufferMeters:
          (data['boundary_buffer_meters'] as num?)?.toDouble() ?? 15,
      maxAccuracyMeters:
          (data['max_accuracy_meters'] as num?)?.toDouble() ?? 100,
      outsideConfirmations: math.max(
        1,
        (data['outside_confirmations'] as num?)?.toInt() ?? 2,
      ),
      insideConfirmations: math.max(
        1,
        (data['inside_confirmations'] as num?)?.toInt() ?? 2,
      ),
      confirmationWindow: Duration(
        seconds: math.max(
          1,
          (data['confirmation_window_seconds'] as num?)?.toInt() ?? 300,
        ),
      ),
      trackingWindowActive: data['tracking_window_active'] == true,
      activeBreach: data['active_breach_id'] != null,
    );
  }

  BoundaryState classify(DeviceLocation location) {
    if (!enabled || polygon.length < 3) return BoundaryState.unknown;
    if (_contains(location.latitude, location.longitude)) {
      return BoundaryState.inside;
    }
    return _distanceToBoundaryMeters(location.latitude, location.longitude) <=
            boundaryBufferMeters
        ? BoundaryState.inside
        : BoundaryState.outside;
  }

  bool _contains(double latitude, double longitude) {
    var inside = false;
    for (
      var index = 0, previous = polygon.length - 1;
      index < polygon.length;
      previous = index++
    ) {
      final a = polygon[previous];
      final b = polygon[index];
      final crosses = (a.latitude > latitude) != (b.latitude > latitude);
      if (crosses &&
          longitude <
              (b.longitude - a.longitude) *
                      (latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  double _distanceToBoundaryMeters(double latitude, double longitude) {
    final latitudeScale = 110540.0;
    final longitudeScale = 111320.0 * math.cos(latitude * math.pi / 180);
    var shortest = double.infinity;

    for (
      var index = 0, previous = polygon.length - 1;
      index < polygon.length;
      previous = index++
    ) {
      final a = polygon[previous];
      final b = polygon[index];
      final ax = (a.longitude - longitude) * longitudeScale;
      final ay = (a.latitude - latitude) * latitudeScale;
      final bx = (b.longitude - longitude) * longitudeScale;
      final by = (b.latitude - latitude) * latitudeScale;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final position = lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
      shortest = math.min(
        shortest,
        math.sqrt(
          math.pow(ax + position * dx, 2) + math.pow(ay + position * dy, 2),
        ),
      );
    }
    return shortest;
  }
}

class StudentLocationSample {
  const StudentLocationSample({
    required this.clientSampleId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
  });

  final String clientSampleId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;

  Map<String, Object?> toMobileJson() => {
    'client_sample_id': clientSampleId,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracyMeters,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'source': 'flutter',
  };
}

class StudentLocationReport {
  const StudentLocationReport({
    required this.accepted,
    required this.boundaryState,
    this.sampleId,
    this.breachEventId,
    this.trackingWindowActive,
    this.breachStatus,
  });

  final bool accepted;
  final BoundaryState boundaryState;
  final int? sampleId;
  final int? breachEventId;
  final bool? trackingWindowActive;
  final String? breachStatus;

  factory StudentLocationReport.fromMobileJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing student location report data.');
    }

    return StudentLocationReport(
      accepted: data['accepted'] as bool? ?? true,
      boundaryState: _parseBoundaryState(data['boundary_state']),
      sampleId: (data['sample_id'] as num?)?.toInt(),
      breachEventId: (data['breach_event_id'] as num?)?.toInt(),
      trackingWindowActive: data['tracking_window_active'] as bool?,
      breachStatus: data['breach_status'] as String?,
    );
  }

  factory StudentLocationReport.fromLegacyJson(Map<String, dynamic> json) {
    return StudentLocationReport(
      accepted: true,
      boundaryState: json['out_of_bounds'] == true
          ? BoundaryState.outside
          : BoundaryState.unknown,
    );
  }

  static BoundaryState _parseBoundaryState(Object? value) => switch (value) {
    'inside' => BoundaryState.inside,
    'outside' => BoundaryState.outside,
    _ => BoundaryState.unknown,
  };
}
