import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/device_location_service.dart';
import '../../domain/student_location.dart';
import '../../domain/student_location_repository.dart';

enum StudentLocationStatus {
  idle,
  checking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  tracking,
  paused,
  failed,
}

class StudentLocationController extends ChangeNotifier {
  StudentLocationController(
    this._repository,
    this._locationService,
    this._accessToken, {
    this.reportInterval = const Duration(minutes: 15),
    this.policyRefreshInterval = const Duration(minutes: 10),
    String Function()? createSampleId,
  }) : _createSampleId = createSampleId ?? const Uuid().v4;

  final StudentLocationRepository _repository;
  final DeviceLocationService _locationService;
  final String _accessToken;
  final Duration reportInterval;
  final Duration policyRefreshInterval;
  final String Function() _createSampleId;

  StudentLocationStatus _status = StudentLocationStatus.idle;
  DeviceLocation? _latestLocation;
  StudentLocationReport? _latestReport;
  StudentLocationConsent? _consent;
  StudentGeofencePolicy? _policy;
  BoundaryState _boundaryState = BoundaryState.unknown;
  BoundaryState? _candidateState;
  final List<StudentLocationSample> _candidateSamples = [];
  DateTime? _policyFetchedAt;
  bool _serverBreachActive = false;
  bool _serverEvaluatesLocation = false;
  DateTime? _lastReportedAt;
  String? _errorMessage;
  Timer? _reportTimer;
  bool _sessionEnabled = false;
  bool _appInForeground = true;
  bool _isReporting = false;
  bool _isConsentLoading = false;
  int _generation = 0;

  StudentLocationStatus get status => _status;
  DeviceLocation? get latestLocation => _latestLocation;
  StudentLocationReport? get latestReport => _latestReport;
  BoundaryState get boundaryState => _boundaryState;
  DateTime? get lastReportedAt => _lastReportedAt;
  String? get errorMessage => _errorMessage;
  bool get isReporting => _isReporting;
  bool get isConsentLoading => _isConsentLoading;
  bool get serverConsentEnabled => _consent?.enabled == true;
  String? get consentPolicyVersion => _consent?.policyVersion;
  bool get isSessionEnabled => _sessionEnabled;
  bool get isTracking => _status == StudentLocationStatus.tracking;

  Future<void> loadConsent() async {
    if (_isConsentLoading) return;
    _isConsentLoading = true;
    notifyListeners();
    try {
      _consent = await _repository.fetchConsent(accessToken: _accessToken);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } on FormatException {
      _errorMessage = 'QRDify returned an invalid consent response.';
    } on Object {
      _errorMessage = 'Unable to check location consent.';
    } finally {
      _isConsentLoading = false;
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (_status == StudentLocationStatus.checking || isTracking) return;
    _sessionEnabled = true;
    _appInForeground = true;
    await _begin(requestPermission: true);
  }

  Future<void> stop() async {
    _sessionEnabled = false;
    _generation++;
    _cancelTimer();
    await _locationService.stopBackgroundTracking();
    _status = StudentLocationStatus.idle;
    _errorMessage = null;
    notifyListeners();
    final consent = _consent;
    if (consent == null || !consent.enabled) return;
    try {
      _consent = await _repository.updateConsent(
        accessToken: _accessToken,
        enabled: false,
        policyVersion: consent.policyVersion,
      );
    } on ApiException catch (error) {
      _errorMessage =
          'Sharing stopped on this phone, but server consent could not be '
          'disabled: ${error.message}';
    } on Object {
      _errorMessage =
          'Sharing stopped on this phone, but server consent could not be '
          'disabled. Connect to the internet and try again.';
    }
    notifyListeners();
  }

  Future<void> pauseForBackground() async {
    // Android keeps the location provider alive with a visible foreground
    // notification. The fifteen-minute timer continues the boundary checks.
    if (!_sessionEnabled) _appInForeground = false;
  }

  Future<void> resumeFromBackground() async {
    _appInForeground = true;
    if (_sessionEnabled && !isTracking) {
      await _begin(requestPermission: false);
    }
  }

  Future<bool> openAppSettings() {
    _sessionEnabled = true;
    return _locationService.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    _sessionEnabled = true;
    return _locationService.openLocationSettings();
  }

  Future<void> _begin({required bool requestPermission}) async {
    final generation = ++_generation;
    _cancelTimer();
    _status = StudentLocationStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _locationService.isServiceEnabled()) {
        if (!_isCurrent(generation)) return;
        _sessionEnabled = false;
        _status = StudentLocationStatus.serviceDisabled;
        notifyListeners();
        return;
      }

      var permission = await _locationService.checkPermission();
      if (permission == DeviceLocationPermission.denied && requestPermission) {
        permission = await _locationService.requestPermission();
      }

      if (!_isCurrent(generation)) return;
      if (permission == DeviceLocationPermission.deniedForever) {
        _sessionEnabled = false;
        _status = StudentLocationStatus.permissionDeniedForever;
        notifyListeners();
        return;
      }
      if (permission == DeviceLocationPermission.denied) {
        _sessionEnabled = false;
        _status = StudentLocationStatus.permissionDenied;
        notifyListeners();
        return;
      }

      var consent = _consent;
      consent ??= await _repository.fetchConsent(accessToken: _accessToken);
      if (!consent.enabled) {
        consent = await _repository.updateConsent(
          accessToken: _accessToken,
          enabled: true,
          policyVersion: consent.policyVersion,
        );
      }
      _consent = consent;
      if (!_isCurrent(generation)) return;

      _status = StudentLocationStatus.tracking;
      await _locationService.startBackgroundTracking(reportInterval);
      _reportTimer = Timer.periodic(
        reportInterval,
        (_) => unawaited(_captureAndEvaluate(generation)),
      );
      notifyListeners();
      await _captureAndEvaluate(generation);
    } on Object {
      if (!_isCurrent(generation)) return;
      _sessionEnabled = false;
      _status = StudentLocationStatus.failed;
      _errorMessage = 'Unable to start location tracking. Please try again.';
      notifyListeners();
    }
  }

  Future<void> checkNow() => _captureAndEvaluate(_generation);

  Future<void> _captureAndEvaluate(int generation) async {
    if (!_isCurrent(generation) || _isReporting) return;

    _isReporting = true;
    notifyListeners();
    try {
      final location = await _locationService.getCurrentLocation();
      if (!_isCurrent(generation)) return;
      _latestLocation = location;

      final sample = StudentLocationSample(
        clientSampleId: _createSampleId(),
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyMeters,
        recordedAt: location.recordedAt,
      );

      if (_serverEvaluatesLocation) {
        await _uploadForServerEvaluation(sample);
        return;
      }

      try {
        await _refreshPolicyIfNeeded();
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        _serverEvaluatesLocation = true;
        await _uploadForServerEvaluation(sample);
        return;
      }
      if (!_isCurrent(generation)) return;
      final policy = _policy;
      if (policy == null || !policy.enabled || !policy.trackingWindowActive) {
        _boundaryState = BoundaryState.unknown;
        _candidateSamples.clear();
        _candidateState = null;
        _errorMessage = null;
        return;
      }
      if (location.accuracyMeters > policy.maxAccuracyMeters) {
        _errorMessage =
            'Location accuracy is too weak. QRDify will check again.';
        return;
      }

      final state = policy.classify(location);
      _boundaryState = state;
      _addCandidate(state, sample, policy.confirmationWindow);

      if (state == BoundaryState.outside) {
        if (_serverBreachActive) {
          await _uploadSamples([sample]);
        } else if (_candidateSamples.length >= policy.outsideConfirmations) {
          await _uploadSamples(
            _candidateSamples
                .skip(_candidateSamples.length - policy.outsideConfirmations)
                .toList(growable: false),
          );
        }
      } else if (state == BoundaryState.inside &&
          _serverBreachActive &&
          _candidateSamples.length >= policy.insideConfirmations) {
        await _uploadSamples(
          _candidateSamples
              .skip(_candidateSamples.length - policy.insideConfirmations)
              .toList(growable: false),
        );
      }

      _errorMessage = null;
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;
      _errorMessage = error.message;
    } on FormatException {
      if (!_isCurrent(generation)) return;
      _errorMessage = 'QRDify returned an invalid location response.';
    } on Object {
      if (!_isCurrent(generation)) return;
      _errorMessage =
          'Unable to get or report location. QRDify will try again.';
    } finally {
      if (_isCurrent(generation)) {
        _isReporting = false;
        notifyListeners();
      }
    }
  }

  Future<void> _uploadForServerEvaluation(StudentLocationSample sample) async {
    await _uploadSamples([sample]);
    _boundaryState = _latestReport?.boundaryState ?? BoundaryState.unknown;
    _errorMessage = null;
  }

  Future<void> _refreshPolicyIfNeeded() async {
    final fetchedAt = _policyFetchedAt;
    if (_policy != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < policyRefreshInterval) {
      return;
    }

    final policy = await _repository.fetchGeofencePolicy(
      accessToken: _accessToken,
    );
    if (_policy?.version != policy.version) {
      _candidateSamples.clear();
      _candidateState = null;
    }
    _policy = policy;
    _policyFetchedAt = DateTime.now();
    _serverBreachActive = policy.activeBreach;
  }

  void _addCandidate(
    BoundaryState state,
    StudentLocationSample sample,
    Duration window,
  ) {
    final windowStart = sample.recordedAt.subtract(window);
    if (_candidateState != state ||
        (_candidateSamples.isNotEmpty &&
            _candidateSamples.last.recordedAt.isBefore(windowStart))) {
      _candidateSamples.clear();
      _candidateState = state;
    }
    _candidateSamples
      ..removeWhere((candidate) => candidate.recordedAt.isBefore(windowStart))
      ..add(sample);
  }

  Future<void> _uploadSamples(List<StudentLocationSample> samples) async {
    for (final sample in samples) {
      final report = await _repository.reportLocation(
        accessToken: _accessToken,
        sample: sample,
      );
      _latestReport = report;
      _lastReportedAt = DateTime.now();
      _serverBreachActive =
          report.breachStatus == 'open' ||
          report.breachStatus == 'acknowledged';
      if (!report.accepted) {
        throw const FormatException('The server rejected the location sample.');
      }
    }
    _candidateSamples.clear();
    _candidateState = null;
  }

  bool _isCurrent(int generation) =>
      generation == _generation && _sessionEnabled && _appInForeground;

  void _cancelTimer() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _isReporting = false;
  }

  @override
  void dispose() {
    _generation++;
    _reportTimer?.cancel();
    unawaited(_locationService.stopBackgroundTracking());
    super.dispose();
  }
}
