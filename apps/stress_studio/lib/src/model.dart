import 'dart:io';

import 'package:flutter/foundation.dart';

int recommendedCpuThreadCount([int? logicalProcessors]) {
  final processors = logicalProcessors ?? Platform.numberOfProcessors;
  if (processors <= 1) {
    return 1;
  }
  return (processors - 1).clamp(1, 64).toInt();
}

@immutable
class RunConfiguration {
  const RunConfiguration({
    required this.duration,
    required this.cpuEnabled,
    required this.cpuLoadPercent,
    required this.cpuThreads,
    required this.gpuEnabled,
    required this.gpuLoadPercent,
    required this.gpuMemoryMiB,
    required this.gpuDeviceIndex,
    this.presetName = 'Custom',
  });

  factory RunConfiguration.defaults() => RunConfiguration(
    duration: const Duration(hours: 1),
    cpuEnabled: true,
    cpuLoadPercent: 65,
    cpuThreads: recommendedCpuThreadCount(),
    gpuEnabled: true,
    gpuLoadPercent: 80,
    gpuMemoryMiB: 192,
    gpuDeviceIndex: 0,
    presetName: 'Balanced',
  );

  factory RunConfiguration.preset(StudioPreset preset) {
    final recommendedWorkers = recommendedCpuThreadCount();
    return switch (preset) {
      StudioPreset.balanced => RunConfiguration(
        duration: const Duration(hours: 1),
        cpuEnabled: true,
        cpuLoadPercent: 65,
        cpuThreads: recommendedWorkers,
        gpuEnabled: true,
        gpuLoadPercent: 80,
        gpuMemoryMiB: 192,
        gpuDeviceIndex: 0,
        presetName: 'Balanced',
      ),
      StudioPreset.cpuValidation => RunConfiguration(
        duration: const Duration(minutes: 30),
        cpuEnabled: true,
        cpuLoadPercent: 85,
        cpuThreads: recommendedWorkers,
        gpuEnabled: false,
        gpuLoadPercent: 0,
        gpuMemoryMiB: 192,
        gpuDeviceIndex: 0,
        presetName: 'CPU validation',
      ),
      StudioPreset.gpuValidation => RunConfiguration(
        duration: const Duration(minutes: 30),
        cpuEnabled: false,
        cpuLoadPercent: 0,
        cpuThreads: recommendedWorkers,
        gpuEnabled: true,
        gpuLoadPercent: 87,
        gpuMemoryMiB: 192,
        gpuDeviceIndex: 0,
        presetName: 'GPU validation',
      ),
      StudioPreset.endurance => RunConfiguration(
        duration: const Duration(hours: 96),
        cpuEnabled: true,
        cpuLoadPercent: 60,
        cpuThreads: recommendedWorkers,
        gpuEnabled: true,
        gpuLoadPercent: 87,
        gpuMemoryMiB: 192,
        gpuDeviceIndex: 0,
        presetName: '96-hour endurance',
      ),
      StudioPreset.quickCheck => RunConfiguration(
        duration: const Duration(minutes: 2),
        cpuEnabled: true,
        cpuLoadPercent: 25,
        cpuThreads: recommendedWorkers,
        gpuEnabled: true,
        gpuLoadPercent: 25,
        gpuMemoryMiB: 96,
        gpuDeviceIndex: 0,
        presetName: 'Quick check',
      ),
    };
  }

  final Duration duration;
  final bool cpuEnabled;
  final double cpuLoadPercent;
  final int cpuThreads;
  final bool gpuEnabled;
  final double gpuLoadPercent;
  final int gpuMemoryMiB;
  final int gpuDeviceIndex;
  final String presetName;

  String? validate() {
    if ((!cpuEnabled || cpuLoadPercent <= 0) &&
        (!gpuEnabled || gpuLoadPercent <= 0)) {
      return 'Enable at least one workload with a target above 0%.';
    }
    if (duration < const Duration(seconds: 1) ||
        duration > const Duration(days: 14)) {
      return 'Duration must be between 1 second and 14 days.';
    }
    if (cpuLoadPercent < 0 || cpuLoadPercent > 100) {
      return 'CPU load must be between 0 and 100 percent.';
    }
    if (gpuLoadPercent < 0 || gpuLoadPercent > 100) {
      return 'GPU load must be between 0 and 100 percent.';
    }
    if (cpuThreads < 1 || cpuThreads > 64) {
      return 'CPU worker count must be between 1 and 64.';
    }
    if (gpuMemoryMiB < 32 || gpuMemoryMiB > 4096) {
      return 'GPU memory budget must be between 32 and 4096 MiB.';
    }
    if (gpuDeviceIndex < 0 || gpuDeviceIndex > 31) {
      return 'GPU device index must be between 0 and 31.';
    }
    return null;
  }

  RunConfiguration copyWith({
    Duration? duration,
    bool? cpuEnabled,
    double? cpuLoadPercent,
    int? cpuThreads,
    bool? gpuEnabled,
    double? gpuLoadPercent,
    int? gpuMemoryMiB,
    int? gpuDeviceIndex,
    String? presetName,
  }) => RunConfiguration(
    duration: duration ?? this.duration,
    cpuEnabled: cpuEnabled ?? this.cpuEnabled,
    cpuLoadPercent: cpuLoadPercent ?? this.cpuLoadPercent,
    cpuThreads: cpuThreads ?? this.cpuThreads,
    gpuEnabled: gpuEnabled ?? this.gpuEnabled,
    gpuLoadPercent: gpuLoadPercent ?? this.gpuLoadPercent,
    gpuMemoryMiB: gpuMemoryMiB ?? this.gpuMemoryMiB,
    gpuDeviceIndex: gpuDeviceIndex ?? this.gpuDeviceIndex,
    presetName: presetName ?? this.presetName,
  );
}

enum StudioPreset {
  balanced,
  cpuValidation,
  gpuValidation,
  endurance,
  quickCheck,
}

enum StudioRunState { idle, starting, running, stopping, completed, error }

extension StudioRunStateLabel on StudioRunState {
  String get label => switch (this) {
    StudioRunState.idle => 'Ready',
    StudioRunState.starting => 'Starting',
    StudioRunState.running => 'Running',
    StudioRunState.stopping => 'Stopping',
    StudioRunState.completed => 'Completed',
    StudioRunState.error => 'Needs attention',
  };
}

@immutable
class CapabilitySnapshot {
  const CapabilitySnapshot({
    required this.operatingSystem,
    required this.logicalProcessors,
    required this.cpuWorkerPath,
    required this.cpuWorkerAvailable,
    required this.gpuWorkerPath,
    required this.gpuWorkerAvailable,
  });

  final String operatingSystem;
  final int logicalProcessors;
  final String cpuWorkerPath;
  final bool cpuWorkerAvailable;
  final String gpuWorkerPath;
  final bool gpuWorkerAvailable;
}

@immutable
class RunRecord {
  const RunRecord({
    required this.startedAt,
    required this.finishedAt,
    required this.configuration,
    required this.completed,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final RunConfiguration configuration;
  final bool completed;

  Duration get elapsed => finishedAt.difference(startedAt);
}
