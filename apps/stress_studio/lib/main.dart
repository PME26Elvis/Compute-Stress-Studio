import 'package:flutter/material.dart';

import 'src/controller.dart';
import 'src/services.dart';
import 'src/studio_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = StudioController(
    cpuService: IsolateCpuStressService(),
    gpuService: JuceGpuWorkerService(),
  );
  runApp(StressStudioApp(controller: controller));
}
