import 'package:flutter_test/flutter_test.dart';
import 'package:stress_studio/src/model.dart';
import 'package:stress_studio/src/services.dart';

void main() {
  test('CPU worker receives duration, load, and thread count', () {
    final configuration = RunConfiguration.defaults().copyWith(
      duration: const Duration(minutes: 15),
      cpuLoadPercent: 62.5,
      cpuThreads: 7,
    );

    expect(buildCpuWorkerArguments(configuration), <String>[
      '--duration',
      '900',
      '--load',
      '62.50',
      '--threads',
      '7',
    ]);
  });

  test('GPU worker contract remains stable', () {
    final configuration = RunConfiguration.defaults().copyWith(
      duration: const Duration(seconds: 30),
      gpuLoadPercent: 87,
      gpuMemoryMiB: 192,
      gpuDeviceIndex: 0,
    );

    expect(buildGpuWorkerArguments(configuration), <String>[
      '--duration',
      '30',
      '--load',
      '87',
      '--memory-mib',
      '192',
      '--device',
      '0',
    ]);
  });

  test('fake CPU availability failure is surfaced', () async {
    final service = FakeCpuStressService(available: false);
    await expectLater(
      service.start(RunConfiguration.defaults()),
      throwsA(isA<StateError>()),
    );
  });
}
