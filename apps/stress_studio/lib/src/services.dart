import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'model.dart';

abstract interface class CpuStressService {
  bool get isRunning;
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

final class IsolateCpuStressService implements CpuStressService {
  final List<Isolate> _isolates = <Isolate>[];

  @override
  bool get isRunning => _isolates.isNotEmpty;

  @override
  Future<void> start(RunConfiguration configuration) async {
    await stop();
    if (!configuration.cpuEnabled || configuration.cpuLoadPercent <= 0) {
      return;
    }

    final command = <String, Object>{
      'load': configuration.cpuLoadPercent,
      'durationMicros': configuration.duration.inMicroseconds,
      'windowMicros': 50000,
    };
    for (var index = 0; index < configuration.cpuThreads; index += 1) {
      _isolates.add(
        await Isolate.spawn<Map<String, Object>>(
          cpuStressWorker,
          command,
          debugName: 'stress-studio-cpu-$index',
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
  }
}

@pragma('vm:entry-point')
void cpuStressWorker(Map<String, Object> command) {
  final load = command['load']! as double;
  final durationMicros = command['durationMicros']! as int;
  final windowMicros = command['windowMicros']! as int;
  final activeMicros = (windowMicros * load / 100).round();
  final idleMicros = math.max(0, windowMicros - activeMicros).toInt();
  final total = Stopwatch()..start();
  var accumulator = 0.61803398875;

  while (total.elapsedMicroseconds < durationMicros) {
    final active = Stopwatch()..start();
    while (active.elapsedMicroseconds < activeMicros) {
      accumulator = math.sqrt(accumulator * accumulator + 1.000000119);
      accumulator = math.sin(accumulator) * math.cos(accumulator + 0.25) + 1.0;
    }
    if (idleMicros > 0) {
      sleep(Duration(microseconds: idleMicros));
    }
  }

  if (accumulator.isNaN) {
    sleep(Duration.zero);
  }
}

final class JuceGpuWorkerService implements GpuStressService {
  Process? _process;

  @override
  bool get isRunning => _process != null;

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
  bool get isAvailable => File(workerPath).existsSync();

  @override
  Future<void> start(RunConfiguration configuration) async {
    await stop();
    if (!configuration.gpuEnabled || configuration.gpuLoadPercent <= 0) {
      return;
    }
    if (!isAvailable) {
      throw StateError('Bundled GPU worker was not found at $workerPath');
    }

    final process = await Process.start(workerPath, <String>[
      '--duration',
      configuration.duration.inSeconds.toString(),
      '--load',
      configuration.gpuLoadPercent.round().toString(),
      '--memory-mib',
      configuration.gpuMemoryMiB.toString(),
      '--device',
      configuration.gpuDeviceIndex.toString(),
    ]);
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

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_process == null) {
      throw StateError(
        'The GPU worker exited during startup. Verify the NVIDIA driver, CUDA compatibility, and selected device.',
      );
    }
  }

  @override
  Future<void> stop() async {
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

final class FakeCpuStressService implements CpuStressService {
  @override
  bool isRunning = false;

  @override
  Future<void> start(RunConfiguration configuration) async {
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
