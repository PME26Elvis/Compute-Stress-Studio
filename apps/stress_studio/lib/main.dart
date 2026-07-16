import 'package:flutter/material.dart';

import 'src/app_owner.dart';
import 'src/controller.dart';
import 'src/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = StudioController(
    cpuService: ProcessCpuStressService(),
    gpuService: JuceGpuWorkerService(),
  );
  runApp(OwnedStressStudioApp(controller: controller));
}
