import 'dart:async';
import 'dart:io';

import 'model.dart';

abstract interface class CpuStressService {
  bool get isRunning;
  String get workerPath;
  bool get isAvailable;
  Future<void> start(RunConfiguration configuration);
  Future<void> stop();
}

abstract interface class GpuStressService {
  bool get isRunning;
  String get workerPath;
  bool get isAvailable;
  Future<void> start(RunConfiguration configuration);
  Future<void> stop();
}

List<String> buildCpuWorkerArguments(RunConfiguration configuration) => <String>[
  '--duration',
  configuration.duration.inSeconds.toString(),
  '--load',
  configuration.cpuLoadPercent.toStringAsFixed(2),
  '--threads',
  configuration.cpuThreads.toString(),
];

List<String> buildGpuWorkerArguments(RunConfiguration configuration) => <String>[
  '--duration',
  configuration.duration.inSeconds.toString(),
  '--load',
  configuration.gpuLoadPercent.round().toString(),
  '--memory-mib',
  configuration.gpuMemoryMiB.toString(),
  '--device',
  configuration.gpuDeviceIndex.toString(),
];

abstract base class _ManagedWorkerProcess {
  Process? _process;

  bool get isRunning => _process != null;
  String get workerPath;
  bool get isAvailable => File(workerPath).existsSync();
  String get displayName;
  List<String> argumentsFor(RunConfiguration configuration);

  Future<void> startWorker(RunConfiguration configuration) async {
    await stopWorker();
    if (!isAvailable) {
      throw StateError('$displayName was not found at $workerPath');
    }

    final process = await Process.start(
      workerPath,
      argumentsFor(configuration),
      mode: ProcessStartMode.normal,
    );
    _process = process;

    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
        }
      }),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_process == null) {
      throw StateError('$displayName exited during startup.');
    }
  }

  Future<void> stopWorker() async {
    final process = _process;
    _process = null;
    if (process == null) {
      return;
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

final class ProcessCpuStressService extends _ManagedWorkerProcess
    implements CpuStressService {
  @override
  String get workerPath {
    final executableName = Platform.isWindows
        ? 'Compute-Stress-CPU-Worker.exe'
        : 'Compute-Stress-CPU-Worker';
    return File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$executableName',
    ).path;
  }

  @override
  String get displayName => 'Bundled CPU worker';

  @override
  List<String> argumentsFor(RunConfiguration configuration) =>
      buildCpuWorkerArguments(configuration);

  @override
  Future<void> start(RunConfiguration configuration) async {
    if (!configuration.cpuEnabled || configuration.cpuLoadPercent <= 0) {
      await stopWorker();
      return;
    }
    await startWorker(configuration);
  }

  @override
  Future<void> stop() => stopWorker();
}

final class JuceGpuWorkerService extends _ManagedWorkerProcess
    implements GpuStressService {
  @override
  String get workerPath {
    final executableName = Platform.isWindows
        ? 'GPU-Stress-JUCE-Background.exe'
        : 'GPU-Stress-JUCE-Background';
    return File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$executableName',
    ).path;
  }

  @override
  String get displayName => 'Bundled GPU worker';

  @override
  List<String> argumentsFor(RunConfiguration configuration) =>
      buildGpuWorkerArguments(configuration);

  @override
  Future<void> start(RunConfiguration configuration) async {
    if (!configuration.gpuEnabled || configuration.gpuLoadPercent <= 0) {
      await stopWorker();
      return;
    }
    try {
      await startWorker(configuration);
    } on StateError catch (error) {
      throw StateError(
        '${error.message} Verify the NVIDIA driver, CUDA compatibility, and selected device.',
      );
    }
  }

  @override
  Future<void> stop() => stopWorker();
}

final class FakeCpuStressService implements CpuStressService {
  FakeCpuStressService({this.available = true});

  final bool available;

  @override
  bool isRunning = false;

  @override
  bool get isAvailable => available;

  @override
  String get workerPath => '/fake/Compute-Stress-CPU-Worker';

  @override
  Future<void> start(RunConfiguration configuration) async {
    if (!available && configuration.cpuEnabled) {
      throw StateError('Fake CPU worker unavailable');
    }
    isRunning = configuration.cpuEnabled;
  }

  @override
  Future<void> stop() async {
    isRunning = false;
  }
}

final class FakeGpuStressService implements GpuStressService {
  FakeGpuStressService({this.available = true});

  final bool available;

  @override
  bool isRunning = false;

  @override
  bool get isAvailable => available;

  @override
  String get workerPath => '/fake/GPU-Stress-JUCE-Background';

  @override
  Future<void> start(RunConfiguration configuration) async {
    if (!available && configuration.gpuEnabled) {
      throw StateError('Fake GPU worker unavailable');
    }
    isRunning = configuration.gpuEnabled;
  }

  @override
  Future<void> stop() async {
    isRunning = false;
  }
}
