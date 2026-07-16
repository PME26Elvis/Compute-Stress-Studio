import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'model.dart';
import 'services.dart';

final class StudioController extends ChangeNotifier {
  StudioController({
    required CpuStressService cpuService,
    required GpuStressService gpuService,
  }) : _cpuService = cpuService,
       _gpuService = gpuService,
       _configuration = RunConfiguration.defaults();

  final CpuStressService _cpuService;
  final GpuStressService _gpuService;
  RunConfiguration _configuration;
  StudioRunState _state = StudioRunState.idle;
  ThemeMode _themeMode = ThemeMode.dark;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _error;
  Timer? _ticker;
  int _selectedPage = 0;
  final List<RunRecord> _history = <RunRecord>[];

  RunConfiguration get configuration => _configuration;
  StudioRunState get state => _state;
  ThemeMode get themeMode => _themeMode;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => _elapsed;
  String? get error => _error;
  int get selectedPage => _selectedPage;
  List<RunRecord> get history => List<RunRecord>.unmodifiable(_history);
  bool get isActive =>
      _state == StudioRunState.starting ||
      _state == StudioRunState.running ||
      _state == StudioRunState.stopping;
  double get progress => _configuration.duration.inMilliseconds == 0
      ? 0.0
      : (_elapsed.inMilliseconds / _configuration.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();
  Duration get remaining {
    final value = _configuration.duration - _elapsed;
    return value.isNegative ? Duration.zero : value;
  }

  CapabilitySnapshot get capabilities => CapabilitySnapshot(
    operatingSystem:
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    logicalProcessors: Platform.numberOfProcessors,
    gpuWorkerPath: _gpuService.workerPath,
    gpuWorkerAvailable: _gpuService.isAvailable,
  );

  void selectPage(int value) {
    if (_selectedPage == value) {
      return;
    }
    _selectedPage = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    notifyListeners();
  }

  void applyPreset(StudioPreset preset) {
    if (isActive) {
      return;
    }
    _configuration = RunConfiguration.preset(preset);
    _error = null;
    notifyListeners();
  }

  void updateConfiguration(RunConfiguration value) {
    if (isActive) {
      return;
    }
    _configuration = value.copyWith(presetName: 'Custom');
    _error = null;
    notifyListeners();
  }

  Future<void> start() async {
    if (isActive) {
      return;
    }
    final validation = _configuration.validate();
    if (validation != null) {
      _state = StudioRunState.error;
      _error = validation;
      notifyListeners();
      return;
    }

    _state = StudioRunState.starting;
    _error = null;
    _elapsed = Duration.zero;
    _startedAt = DateTime.now();
    notifyListeners();

    try {
      await Future.wait<void>(<Future<void>>[
        _cpuService.start(_configuration),
        _gpuService.start(_configuration),
      ]);
      _state = StudioRunState.running;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final startedAt = _startedAt;
        if (startedAt == null) {
          return;
        }
        _elapsed = DateTime.now().difference(startedAt);
        if (_elapsed >= _configuration.duration) {
          unawaited(stop(completed: true));
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
    } catch (exception) {
      await Future.wait<void>(<Future<void>>[
        _cpuService.stop(),
        _gpuService.stop(),
      ]);
      _state = StudioRunState.error;
      _error = exception.toString();
      notifyListeners();
    }
  }

  Future<void> stop({bool completed = false}) async {
    if (!isActive) {
      return;
    }
    _state = StudioRunState.stopping;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();

    await Future.wait<void>(<Future<void>>[
      _cpuService.stop(),
      _gpuService.stop(),
    ]);

    final startedAt = _startedAt;
    final finishedAt = DateTime.now();
    if (startedAt != null) {
      _elapsed = finishedAt.difference(startedAt);
      _history.insert(
        0,
        RunRecord(
          startedAt: startedAt,
          finishedAt: finishedAt,
          configuration: _configuration,
          completed: completed,
        ),
      );
      if (_history.length > 20) {
        _history.removeLast();
      }
    }
    _state = completed ? StudioRunState.completed : StudioRunState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_cpuService.stop());
    unawaited(_gpuService.stop());
    super.dispose();
  }
}
