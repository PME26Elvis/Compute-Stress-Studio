import 'package:flutter_test/flutter_test.dart';
import 'package:stress_studio/src/controller.dart';
import 'package:stress_studio/src/model.dart';
import 'package:stress_studio/src/services.dart';

void main() {
  test('coordinator starts and stops both services', () async {
    final cpu = FakeCpuStressService();
    final gpu = FakeGpuStressService();
    final controller = StudioController(cpuService: cpu, gpuService: gpu);

    await controller.start();
    expect(controller.state, StudioRunState.running);
    expect(cpu.isRunning, isTrue);
    expect(gpu.isRunning, isTrue);

    await controller.stop();
    expect(controller.state, StudioRunState.idle);
    expect(cpu.isRunning, isFalse);
    expect(gpu.isRunning, isFalse);
    expect(controller.history, hasLength(1));
  });

  test('GPU startup failure rolls back CPU service', () async {
    final cpu = FakeCpuStressService();
    final controller = StudioController(
      cpuService: cpu,
      gpuService: FakeGpuStressService(available: false),
    );

    await controller.start();
    expect(controller.state, StudioRunState.error);
    expect(cpu.isRunning, isFalse);
    expect(controller.error, isNotNull);
  });
}
