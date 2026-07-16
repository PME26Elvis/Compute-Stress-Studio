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
          title: 'Stress Studio',
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
        SingleActivator(LogicalKeyboardKey.enter, control: true): StartRunIntent(),
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
              final wide = constraints.maxWidth >= 1100;
              final compact = constraints.maxWidth < 760;
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
                    destinations: const <NavigationDestination>[
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_rounded),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: 'Presets',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.monitor_heart_rounded),
                        label: 'Diagnostics',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_rounded),
                        label: 'Settings',
                      ),
                    ],
                  ),
                );
              }
              return Scaffold(
                body: Row(
                  children: <Widget>[
                    NavigationRail(
                      extended: wide,
                      minExtendedWidth: 220,
                      selectedIndex: controller.selectedPage,
                      onDestinationSelected: controller.selectPage,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 18),
                        child: wide
                            ? const _BrandLockup()
                            : const Icon(Icons.speed_rounded, size: 30),
                      ),
                      destinations: const <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_rounded),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_rounded),
                          label: Text('Presets'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.monitor_heart_rounded),
                          label: Text('Diagnostics'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_rounded),
                          label: Text('Settings'),
                        ),
                      ],
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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            sliver: SliverToBoxAdapter(child: _StatusGrid(controller: controller)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 980;
                  final composer = WorkloadComposer(controller: controller);
                  final activity = ActivityPanel(controller: controller);
                  if (stack) {
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
          final compact = constraints.maxWidth < 700;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _StatePill(state: controller.state),
                  const SizedBox(width: 10),
                  Text(controller.configuration.presetName),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Coordinate CPU + GPU stress\nfrom one modern control plane.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Flutter owns the adaptive desktop experience. Isolates and the silent JUCE WaveMix worker own the workloads.',
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
          if (compact) {
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
          final width = constraints.maxWidth;
          final columns = width > 1050 ? 4 : width > 620 ? 2 : 1;
          final cardWidth = (width - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _MetricCard(
                width: cardWidth,
                icon: Icons.timer_outlined,
                label: 'Elapsed',
                value: _formatDuration(controller.elapsed),
                detail: '${(controller.progress * 100).toStringAsFixed(1)}% of session',
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.memory_rounded,
                label: 'CPU target',
                value: controller.configuration.cpuEnabled
                    ? '${controller.configuration.cpuLoadPercent.round()}%'
                    : 'Off',
                detail: '${controller.configuration.cpuThreads} isolate workers',
              ),
              _MetricCard(
                width: cardWidth,
                icon: Icons.developer_board_rounded,
                label: 'GPU target',
                value: controller.configuration.gpuEnabled
                    ? '${controller.configuration.gpuLoadPercent.round()}%'
                    : 'Off',
                detail:
                    '${controller.configuration.gpuMemoryMiB} MiB WaveMix budget',
              ),
              _MetricCard(
                width: cardWidth,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Workload composer',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Changes lock while a session is active.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _WorkloadSection(
              icon: Icons.memory_rounded,
              title: 'CPU engine',
              subtitle: 'Dart isolate workers with a short duty-cycle window',
              enabled: config.cpuEnabled,
              onEnabled: controller.isActive
                  ? null
                  : (value) => controller.updateConfiguration(
                        config.copyWith(cpuEnabled: value),
                      ),
              children: <Widget>[
                _LabeledSlider(
                  label: 'Target load',
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
                  label: 'Worker isolates',
                  valueLabel: '${config.cpuThreads}',
                  value: config.cpuThreads.toDouble(),
                  min: 1,
                  max: math
                      .max(2, controller.capabilities.logicalProcessors)
                      .toDouble(),
                  divisions:
                      math.max(1, controller.capabilities.logicalProcessors - 1),
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
                  label: 'VRAM budget',
                  valueLabel: '${config.gpuMemoryMiB} MiB',
                  value: config.gpuMemoryMiB.toDouble(),
                  min: 32,
                  max: 1024,
                  divisions: 62,
                  onChanged: controller.isActive
                      ? null
                      : (value) => controller.updateConfiguration(
                            config.copyWith(
                              gpuMemoryMiB: (value / 16).round() * 16,
                            ),
                          ),
                ),
              ],
            ),
            const Divider(height: 40),
            Text(
              'Session length',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Duration>[
                const Duration(minutes: 2),
                const Duration(minutes: 30),
                const Duration(hours: 1),
                const Duration(hours: 8),
                const Duration(hours: 24),
                const Duration(hours: 96),
              ].map((duration) {
                final selected = config.duration == duration;
                return ChoiceChip(
                  label: Text(_formatDuration(duration)),
                  selected: selected,
                  onSelected: controller.isActive
                      ? null
                      : (_) => controller.updateConfiguration(
                            config.copyWith(duration: duration),
                          ),
                );
              }).toList(),
            ),
            if (controller.error != null) ...<Widget>[
              const SizedBox(height: 20),
              _InlineError(message: controller.error!),
            ],
          ],
        ),
      ),
    );
  }
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
                'Live command view',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Targets and worker lifecycle; use your preferred external telemetry monitor for physical readings.',
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Gauge(
                      label: 'CPU',
                      value: controller.configuration.cpuEnabled
                          ? controller.configuration.cpuLoadPercent / 100
                          : 0,
                      centre: controller.configuration.cpuEnabled
                          ? '${controller.configuration.cpuLoadPercent.round()}%'
                          : 'Off',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Gauge(
                      label: 'GPU',
                      value: controller.configuration.gpuEnabled
                          ? controller.configuration.gpuLoadPercent / 100
                          : 0,
                      centre: controller.configuration.gpuEnabled
                          ? '${controller.configuration.gpuLoadPercent.round()}%'
                          : 'Off',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(_formatDuration(controller.elapsed)),
                  Text(_formatDuration(controller.configuration.duration)),
                ],
              ),
              const SizedBox(height: 26),
              _ActivityRow(
                icon: Icons.layers_rounded,
                label: 'Preset',
                value: controller.configuration.presetName,
              ),
              _ActivityRow(
                icon: Icons.memory_rounded,
                label: 'CPU workers',
                value: '${controller.configuration.cpuThreads}',
              ),
              _ActivityRow(
                icon: Icons.developer_board_rounded,
                label: 'GPU device',
                value: '${controller.configuration.gpuDeviceIndex}',
              ),
              _ActivityRow(
                icon: controller.capabilities.gpuWorkerAvailable
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                label: 'GPU worker',
                value: controller.capabilities.gpuWorkerAvailable
                    ? 'Bundled'
                    : 'Missing',
              ),
            ],
          ),
        ),
      );
}

final class PresetsPage extends StatelessWidget {
  const PresetsPage({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final presets = <(StudioPreset, String, String, IconData)>[
      (
        StudioPreset.quickCheck,
        'Quick check',
        'Two minutes at 25% on CPU and GPU.',
        Icons.bolt_rounded,
      ),
      (
        StudioPreset.balanced,
        'Balanced',
        'A one-hour mixed compute validation.',
        Icons.balance_rounded,
      ),
      (
        StudioPreset.cpuValidation,
        'CPU validation',
        'Thirty minutes at 85% across logical processors.',
        Icons.memory_rounded,
      ),
      (
        StudioPreset.gpuValidation,
        'GPU validation',
        'Thirty minutes at the P2200-oriented 87% target.',
        Icons.developer_board_rounded,
      ),
      (
        StudioPreset.endurance,
        '96-hour endurance',
        'Long-duration mixed load with conservative CPU duty.',
        Icons.all_inclusive_rounded,
      ),
    ];
    return _PageFrame(
      title: 'Presets',
      subtitle:
          'Opinionated starting points remain editable on the dashboard.',
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 1000
                ? 3
                : constraints.maxWidth > 620
                    ? 2
                    : 1,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.45,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final preset = presets[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
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
                      const Spacer(),
                      Text(
                        preset.$2,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(preset.$3),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({required this.controller, super.key});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final capabilities = controller.capabilities;
    return _PageFrame(
      title: 'Diagnostics',
      subtitle:
          'Capability checks are intentionally separate from workload controls.',
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
            icon: Icons.developer_board_rounded,
            title: 'Bundled GPU worker',
            value: capabilities.gpuWorkerPath,
            ok: capabilities.gpuWorkerAvailable,
          ),
          const _DiagnosticTile(
            icon: Icons.shield_outlined,
            title: 'Monitoring policy',
            value:
                'Stress Studio does not poll nvidia-smi or write telemetry files. External monitoring remains recommended.',
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
        subtitle:
            'Local presentation preferences. Workload settings live on the dashboard.',
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
                const SizedBox(height: 24),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.keyboard_rounded),
                  title: Text('Keyboard controls'),
                  subtitle: Text('Ctrl+Enter starts a session. Escape stops it.'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.architecture_rounded),
                  title: Text('Execution boundary'),
                  subtitle: Text(
                    'CPU uses killable isolates; GPU uses the bundled silent JUCE background executable.',
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 26),
              child,
            ],
          ),
        ),
      );
}

final class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.speed_rounded, size: 28),
            SizedBox(width: 10),
            Text(
              'Stress Studio',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: 0.72),
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
            Text(
              state.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(subtitle),
                    ],
                  ),
                ),
                Switch(value: enabled, onChanged: onEnabled),
              ],
            ),
            if (enabled) ...<Widget>[
              const SizedBox(height: 18),
              ...children,
            ],
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
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(label),
                Text(
                  valueLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      );
}

final class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.value,
    required this.centre,
  });

  final String label;
  final double value;
  final String centre;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _GaugePainter(
                progress: value,
                track: Theme.of(context).colorScheme.surfaceContainerHighest,
                active: Theme.of(context).colorScheme.primary,
              ),
              child: Center(
                child: Text(
                  centre,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

final class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.track,
    required this.active,
  });

  final double progress;
  final Color track;
  final Color active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.09;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    paint.color = track;
    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      paint,
    );
    paint.color = active;
    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi * 0.75,
      math.pi * 1.5 * progress.clamp(0, 1).toDouble(),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.active != active;
}

final class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

final class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
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
        margin: const EdgeInsets.only(bottom: 14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(value),
          trailing: Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? StudioTheme.accent : StudioTheme.warning,
          ),
        ),
      );
}

String _formatDuration(Duration duration) {
  final totalSeconds = math.max(0, duration.inSeconds);
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (days > 0) {
    return '${days}d ${hours}h';
  }
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}
