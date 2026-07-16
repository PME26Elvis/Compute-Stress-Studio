import 'package:flutter/material.dart';

import 'controller.dart';
import 'studio_app.dart';

/// Production root that owns the controller and therefore the workload
/// lifecycle. Removing this widget synchronously begins stopping CPU isolates
/// and the bundled GPU worker before the Flutter engine shuts down.
final class OwnedStressStudioApp extends StatefulWidget {
  const OwnedStressStudioApp({required this.controller, super.key});

  final StudioController controller;

  @override
  State<OwnedStressStudioApp> createState() => _OwnedStressStudioAppState();
}

final class _OwnedStressStudioAppState extends State<OwnedStressStudioApp> {
  @override
  Widget build(BuildContext context) =>
      StressStudioApp(controller: widget.controller);

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
}
