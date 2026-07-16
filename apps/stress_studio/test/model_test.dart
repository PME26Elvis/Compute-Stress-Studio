import 'package:flutter_test/flutter_test.dart';
import 'package:stress_studio/src/model.dart';

void main() {
  test('defaults enable coordinated CPU and GPU workloads', () {
    final configuration = RunConfiguration.defaults();
    expect(configuration.cpuEnabled, isTrue);
    expect(configuration.gpuEnabled, isTrue);
    expect(configuration.validate(), isNull);
  });

  test('recommended CPU count reserves one logical processor', () {
    expect(recommendedCpuThreadCount(1), 1);
    expect(recommendedCpuThreadCount(2), 1);
    expect(recommendedCpuThreadCount(8), 7);
    expect(recommendedCpuThreadCount(128), 64);
  });

  test('configuration rejects an empty workload', () {
    final configuration = RunConfiguration.defaults().copyWith(
      cpuEnabled: false,
      gpuEnabled: false,
    );
    expect(configuration.validate(), contains('Enable at least one'));
  });

  test('endurance preset keeps the personalized GPU target', () {
    final configuration = RunConfiguration.preset(StudioPreset.endurance);
    expect(configuration.duration, const Duration(hours: 96));
    expect(configuration.gpuLoadPercent, 87);
    expect(configuration.gpuMemoryMiB, 192);
  });
}
