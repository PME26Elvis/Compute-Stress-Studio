import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'model.dart';
import 'theme.dart';

final class StressStudioApp extends StatelessWidget {
  const StressStudioApp({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'Compute Stress Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.light(),
      darkTheme: StudioTheme.dark(),
      themeMode: controller.themeMode,
      home: StudioShell(controller: controller),
    ),
  );
}

final class StudioShell extends StatelessWidget {
  const StudioShell({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(controller: controller),
      PresetsPage(controller: controller),
      DiagnosticsPage(controller: controller),
      SettingsPage(controller: controller),
    ];

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            StartRunIntent(),
        SingleActivator(LogicalKeyboardKey.escape): StopRunIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          StartRunIntent: CallbackAction<StartRunIntent>(
            onInvoke: (_) {
              unawaited(controller.start());
              return null;
            },
          ),
          StopRunIntent: CallbackAction<StopRunIntent>(
            onInvoke: (_) {
              unawaited(controller.stop());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final expandedRail = constraints.maxWidth >= 1120;
              final content = AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey<int>(controller.selectedPage),
                  child: pages[controller.selectedPage],
                ),
              );

              if (compact) {
                return Scaffold(
                  body: SafeArea(child: content),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: controller.selectedPage,
                    onDestinationSelected: controller.selectPage,
                    destinations: _navigationDestinations,
                  ),
                );
              }

              return Scaffold(
                body: Row(
                  children: <Widget>[
                    NavigationRail(
                      extended: expandedRail,
                      minExtendedWidth: 232,
                      selectedIndex: controller.selectedPage,
                      onDestinationSelected: controller.selectPage,
                      leading: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                        child: expandedRail
                            ? const _BrandLockup()
                            : const Icon(Icons.speed_rounded, size: 30),
                      ),
                      destinations: _railDestinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: SafeArea(child: content)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

const _navigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.dashboard_rounded),
    label: 'Dashboard',
  ),
  NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Presets'),
  NavigationDestination(
    icon: Icon(Icons.fact_check_rounded),
    label: 'Diagnostics',
  ),
  NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
];

const _railDestinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: Icon(Icons.dashboard_rounded),
    label: Text('Dashboard'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.tune_rounded),
    label: Text('Presets'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.fact_check_rounded),
    label: Text('Diagnostics'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.settings_rounded),
    label: Text('Settings'),
  ),
];

final class StartRunIntent extends Intent {
  const StartRunIntent();
}

final class StopRunIntent extends Intent {
  const StopRunIntent();
}

final class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
        sliver: SliverToBoxAdapter(child: _HeroPanel(controller: controller)),
      ),
      if (controller.error != null)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _ErrorBanner(message: controller.error!),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        sliver: SliverToBoxAdapter(child: _StatusGrid(controller: controller)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
        sliver: SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final composer = WorkloadComposer(controller: controller);
              final activity = ActivityPanel(controller: controller);
              if (constraints.maxWidth < 980) {
                return Column(
                  children: <Widget>[
                    composer,
                    const SizedBox(height: 18),
                    activity,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 7, child: composer),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: activity),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

final class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: <Color>[scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _StatePill(state: controller.state),
                  Text(
                    controller.configuration.presetName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'CPU + GPU stress without\nfreezing the control plane.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Flutter stays responsive while dedicated low-priority CPU and JUCE CUDA worker processes own the workloads.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );

          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: controller.isActive
                    ? null
                    : () => unawaited(controller.start()),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start session  Ctrl+Enter'),
              ),
              OutlinedButton.icon(
                onPressed: controller.isActive
                    ? () => unawaited(controller.stop())
                    : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop  Esc'),
              ),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[copy, const SizedBox(height: 24), actions],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: copy),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

final class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 1050
          ? 4
          : constraints.maxWidth > 620
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      final config = controller.configuration;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: <Widget>[
          _MetricCard(
            width: width,
            icon: Icons.timer_outlined,
            label: 'Elapsed',
            value: _formatDuration(controller.elapsed),
            detail:
                '${(controller.progress * 100).toStringAsFixed(1)}% of session',
          ),
          _MetricCard(
            width: width,
            icon: Icons.memory_rounded,
            label: 'CPU target',
            value: config.cpuEnabled
                ? '${config.cpuLoadPercent.round()}%'
                : 'Off',
            detail: '${config.cpuThreads} low-priority threads',
          ),
          _MetricCard(
            width: width,
            icon: Icons.developer_board_rounded,
            label: 'GPU target',
            value: config.gpuEnabled
                ? '${config.gpuLoadPercent.round()}%'
                : 'Off',
            detail: '${config.gpuMemoryMiB} MiB WaveMix budget',
          ),
          _MetricCard(
            width: width,
            icon: Icons.schedule_rounded,
            label: 'Remaining',
            value: _formatDuration(controller.remaining),
            detail: controller.state.label,
          ),
        ],
      );
    },
  );
}

final class WorkloadComposer extends StatelessWidget {
  const WorkloadComposer({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.configuration;
    final processors = math.max(1, controller.capabilities.logicalProcessors);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Workload composer',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Settings lock while a session is active. Presets reserve one logical processor by default.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _WorkloadSection(
              icon: Icons.memory_rounded,
              title: 'CPU engine',
              subtitle: 'Bundled low-priority CPU worker process',
              enabled: config.cpuEnabled,
              onEnabled: controller.isActive
                  ? null
                  : (value) => controller.updateConfiguration(
                      config.copyWith(cpuEnabled: value),
                    ),
              children: <Widget>[
                _LabeledSlider(
                  label: 'Target duty load',
                  valueLabel: '${config.cpuLoadPercent.round()}%',
                  value: config.cpuLoadPercent,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                          config.copyWith(cpuLoadPercent: value),
                        ),
                ),
                _LabeledSlider(
                  label: 'CPU worker threads',
                  valueLabel: '${config.cpuThreads}',
                  value: config.cpuThreads.toDouble().clamp(
                    1,
                    math.max(1, processors).toDouble(),
                  ),
                  min: 1,
                  max: math.max(2, processors).toDouble(),
                  divisions: math.max(1, processors - 1),
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                          config.copyWith(cpuThreads: value.round()),
                        ),
                ),
              ],
            ),
            const Divider(height: 40),
            _WorkloadSection(
              icon: Icons.developer_board_rounded,
              title: 'NVIDIA GPU engine',
              subtitle: 'Bundled silent JUCE CUDA WaveMix worker',
              enabled: config.gpuEnabled,
              onEnabled: controller.isActive
                  ? null
                  : (value) => controller.updateConfiguration(
                      config.copyWith(gpuEnabled: value),
                    ),
              children: <Widget>[
                _LabeledSlider(
                  label: 'Target duty load',
                  valueLabel: '${config.gpuLoadPercent.round()}%',
                  value: config.gpuLoadPercent,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                          config.copyWith(gpuLoadPercent: value),
                        ),
                ),
                _LabeledSlider(
                  label: 'WaveMix VRAM budget',
                  valueLabel: '${config.gpuMemoryMiB} MiB',
                  value: config.gpuMemoryMiB.toDouble(),
                  min: 32,
                  max: 1024,
                  divisions: 31,
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                          config.copyWith(
                            gpuMemoryMiB: (value / 32).round() * 32,
                          ),
                        ),
                ),
                _LabeledSlider(
                  label: 'CUDA device index',
                  valueLabel: '${config.gpuDeviceIndex}',
                  value: config.gpuDeviceIndex.toDouble(),
                  min: 0,
                  max: 7,
                  divisions: 7,
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                          config.copyWith(gpuDeviceIndex: value.round()),
                        ),
                ),
              ],
            ),
            const Divider(height: 40),
            Text(
              'Session duration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DurationChoice(
                  label: '2 min',
                  duration: const Duration(minutes: 2),
                  controller: controller,
                ),
                _DurationChoice(
                  label: '30 min',
                  duration: const Duration(minutes: 30),
                  controller: controller,
                ),
                _DurationChoice(
                  label: '1 hour',
                  duration: const Duration(hours: 1),
                  controller: controller,
                ),
                _DurationChoice(
                  label: '96 hours',
                  duration: const Duration(hours: 96),
                  controller: controller,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.label,
    required this.duration,
    required this.controller,
  });

  final String label;
  final Duration duration;
  final StudioController controller;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: controller.configuration.duration == duration,
    onSelected: controller.isActive
        ? null
        : (_) => controller.updateConfiguration(
            controller.configuration.copyWith(duration: duration),
          ),
  );
}

final class ActivityPanel extends StatelessWidget {
  const ActivityPanel({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Session control',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _WorkerReadiness(
            label: 'CPU worker',
            ready: controller.capabilities.cpuWorkerAvailable,
          ),
          const SizedBox(height: 10),
          _WorkerReadiness(
            label: 'GPU worker',
            ready: controller.capabilities.gpuWorkerAvailable,
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 12),
          Text(
            controller.isActive
                ? 'Both workers remain external to Flutter, keeping this control surface schedulable.'
                : 'Ready for a coordinated session.',
          ),
          const SizedBox(height: 24),
          Text(
            'Recent sessions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (controller.history.isEmpty)
            const Text('No completed or stopped sessions in this app session.')
          else
            ...controller.history
                .take(5)
                .map(
                  (record) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      record.completed
                          ? Icons.check_circle_outline_rounded
                          : Icons.stop_circle_outlined,
                    ),
                    title: Text(record.configuration.presetName),
                    subtitle: Text(_formatDuration(record.elapsed)),
                  ),
                ),
        ],
      ),
    ),
  );
}

final class _WorkerReadiness extends StatelessWidget {
  const _WorkerReadiness({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(
        ready ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: ready ? StudioTheme.accent : Theme.of(context).colorScheme.error,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      Text(ready ? 'Ready' : 'Missing'),
    ],
  );
}

final class PresetsPage extends StatelessWidget {
  const PresetsPage({required this.controller, super.key});

  final StudioController controller;

  static const presets = <(StudioPreset, String, String, IconData)>[
    (
      StudioPreset.quickCheck,
      'Quick check',
      '2 minutes at 25% CPU and GPU. Use this first.',
      Icons.flash_on_rounded,
    ),
    (
      StudioPreset.balanced,
      'Balanced',
      '1 hour with moderate CPU and GPU targets.',
      Icons.balance_rounded,
    ),
    (
      StudioPreset.cpuValidation,
      'CPU validation',
      '30 minutes of CPU-only loading.',
      Icons.memory_rounded,
    ),
    (
      StudioPreset.gpuValidation,
      'GPU validation',
      '30 minutes at the personalized 87% GPU duty target.',
      Icons.developer_board_rounded,
    ),
    (
      StudioPreset.endurance,
      '96-hour endurance',
      'Long coordinated run. Validate cooling first.',
      Icons.timelapse_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Presets',
    subtitle: 'Apply a known starting point, then review it on the Dashboard.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050
            ? 3
            : constraints.maxWidth > 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: presets
              .map(
                (preset) => SizedBox(
                  width: width,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: controller.isActive
                          ? null
                          : () {
                              controller.applyPreset(preset.$1);
                              controller.selectPage(0);
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(preset.$4, size: 30),
                            const SizedBox(height: 24),
                            Text(
                              preset.$2,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(preset.$3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

final class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final capabilities = controller.capabilities;
    return _PageFrame(
      title: 'Diagnostics',
      subtitle: 'Capability checks do not start a workload.',
      child: Column(
        children: <Widget>[
          _DiagnosticTile(
            icon: Icons.desktop_windows_rounded,
            title: 'Operating system',
            value: capabilities.operatingSystem,
            ok: true,
          ),
          _DiagnosticTile(
            icon: Icons.memory_rounded,
            title: 'Logical processors',
            value: '${capabilities.logicalProcessors}',
            ok: capabilities.logicalProcessors > 0,
          ),
          _DiagnosticTile(
            icon: Icons.speed_rounded,
            title: 'Bundled CPU worker',
            value: capabilities.cpuWorkerPath,
            ok: capabilities.cpuWorkerAvailable,
          ),
          _DiagnosticTile(
            icon: Icons.developer_board_rounded,
            title: 'Bundled GPU worker',
            value: capabilities.gpuWorkerPath,
            ok: capabilities.gpuWorkerAvailable,
          ),
          const _DiagnosticTile(
            icon: Icons.shield_outlined,
            title: 'Monitoring policy',
            value:
                'Compute Stress Studio does not poll nvidia-smi or write telemetry files. Use an external monitor for physical readings.',
            ok: true,
          ),
        ],
      ),
    );
  }
}

final class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Settings',
    subtitle: 'Presentation preferences and execution policy.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_suggest_rounded),
                  label: Text('System'),
                ),
              ],
              selected: <ThemeMode>{controller.themeMode},
              onSelectionChanged: (value) =>
                  controller.setThemeMode(value.first),
            ),
            const SizedBox(height: 22),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.keyboard_rounded),
              title: Text('Keyboard controls'),
              subtitle: Text('Ctrl+Enter starts. Escape stops.'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_tree_rounded),
              title: Text('Execution boundary'),
              subtitle: Text(
                'CPU and GPU run in separate bundled worker processes so the Flutter window remains responsive.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.low_priority_rounded),
              title: Text('Responsiveness guard'),
              subtitle: Text(
                'Presets reserve one logical processor and the CPU worker lowers its OS priority. Full-thread loading remains an explicit choice.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 26),
            child,
          ],
        ),
      ),
    ),
  );
}

final class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.speed_rounded, size: 28),
        SizedBox(width: 10),
        Text(
          'Compute Stress Studio',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

final class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final StudioRunState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: state == StudioRunState.running
                ? StudioTheme.accent
                : Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(state.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _WorkloadSection extends StatelessWidget {
  const _WorkloadSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onEnabled,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool>? onEnabled;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 180),
    opacity: enabled ? 1 : 0.55,
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: onEnabled),
          ],
        ),
        if (enabled) ...<Widget>[const SizedBox(height: 18), ...children],
      ],
    ),
  );
}

final class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

final class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(value),
      trailing: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_rounded,
        color: ok ? StudioTheme.accent : Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
