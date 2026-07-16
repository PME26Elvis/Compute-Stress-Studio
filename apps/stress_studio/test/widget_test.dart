import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stress_studio/src/controller.dart';
import 'package:stress_studio/src/services.dart';
import 'package:stress_studio/src/studio_app.dart';

void main() {
  testWidgets('dashboard exposes coordinated workload controls', (
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

    expect(find.text('Workload composer'), findsOneWidget);
    expect(find.text('CPU engine'), findsOneWidget);
    expect(find.text('NVIDIA GPU engine'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Start session  Ctrl+Enter'),
      findsOneWidget,
    );
  });
}
