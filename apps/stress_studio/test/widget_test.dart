import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stress_studio/src/app_owner.dart';
import 'package:stress_studio/src/controller.dart';
import 'package:stress_studio/src/services.dart';
import 'package:stress_studio/src/studio_app.dart';

void main() {
  testWidgets('dashboard exposes responsive out-of-process workloads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StudioController(
      cpuService: FakeCpuStressService(),
      gpuService: FakeGpuStressService(),
    );
    await tester.pumpWidget(StressStudioApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Compute Stress Studio'), findsOneWidget);
    expect(find.text('Workload composer'), findsOneWidget);
    expect(find.text('CPU engine'), findsOneWidget);
    expect(find.text('NVIDIA GPU engine'), findsOneWidget);
    expect(find.textContaining('low-priority CPU worker'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Start session  Ctrl+Enter'),
      findsOneWidget,
    );

    controller.selectPage(2);
    await tester.pumpAndSettle();
    expect(find.text('Bundled CPU worker'), findsOneWidget);
    expect(find.text('Bundled GPU worker'), findsOneWidget);
  });

  testWidgets('owned app stops active workers when removed', (tester) async {
    final cpu = FakeCpuStressService();
    final gpu = FakeGpuStressService();
    final controller = StudioController(cpuService: cpu, gpuService: gpu);
    await controller.start();
    expect(cpu.isRunning, isTrue);
    expect(gpu.isRunning, isTrue);

    await tester.pumpWidget(OwnedStressStudioApp(controller: controller));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cpu.isRunning, isFalse);
    expect(gpu.isRunning, isFalse);
  });
}
