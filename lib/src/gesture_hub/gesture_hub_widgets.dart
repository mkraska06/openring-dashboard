import 'package:flutter/material.dart';

import 'gesture_hub_controller.dart';

class GestureHubCard extends StatelessWidget {
  const GestureHubCard({
    super.key,
    required this.state,
    required this.sensorRunning,
    required this.sensorStopping,
    required this.onControlSelected,
    required this.onToggle,
  });

  final GestureHubState state;
  final bool sensorRunning;
  final bool sensorStopping;
  final ValueChanged<GestureHubControl> onControlSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensorText = sensorStopping
        ? 'Sensor stopping'
        : sensorRunning
        ? 'Sensor active'
        : 'Sensor ready';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.gesture, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('Gesture Hub', style: theme.textTheme.titleMedium),
                const Spacer(),
                _StatusPill(
                  label: state.isActive ? 'Active' : 'Inactive',
                  active: state.isActive,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Volume'),
                  selected: state.selectedControl == GestureHubControl.volume,
                  onSelected: state.isActive
                      ? null
                      : (_) => onControlSelected(GestureHubControl.volume),
                ),
                ChoiceChip(
                  label: const Text('Scroll'),
                  selected: state.selectedControl == GestureHubControl.scroll,
                  onSelected: state.isActive
                      ? null
                      : (_) => onControlSelected(GestureHubControl.scroll),
                ),
                ChoiceChip(
                  label: const Text('Mouse'),
                  selected: state.selectedControl == GestureHubControl.mouse,
                  onSelected: state.isActive
                      ? null
                      : (_) => onControlSelected(GestureHubControl.mouse),
                ),
                _MetricChip(label: sensorText),
                if (state.selectedControl == GestureHubControl.volume &&
                    state.volume != null)
                  _MetricChip(label: '${(state.volume! * 100).round()}%'),
                if (state.selectedControl == GestureHubControl.mouse)
                  _MetricChip(label: _mouseAxisLabel(state.mouseAxis)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: sensorStopping ? null : onToggle,
                  icon: Icon(state.isActive ? Icons.stop : Icons.play_arrow),
                  label: Text(state.isActive ? 'Stop' : 'Activate'),
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 6),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GestureHubOverlay extends StatelessWidget {
  const GestureHubOverlay({super.key, required this.state});

  final GestureHubState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _overlayLabels(state.selectedControl, state.mouseAxis);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gesture, size: 18),
                      const SizedBox(width: 8),
                      Text('Gesture Hub', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      if (state.selectedControl == GestureHubControl.volume)
                        Text(
                          state.volume == null
                              ? '--%'
                              : '${(state.volume! * 100).round()}%',
                          style: theme.textTheme.titleMedium,
                        )
                      else if (state.selectedControl == GestureHubControl.mouse)
                        Text(
                          _mouseAxisLabel(state.mouseAxis),
                          style: theme.textTheme.titleMedium,
                        )
                      else
                        Icon(
                          Icons.mouse_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PositionTile(
                          label: labels.downLabel,
                          icon: labels.downIcon,
                          active: state.position == GestureHubPosition.palmDown,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PositionTile(
                          label: labels.sideLabel,
                          icon: labels.sideIcon,
                          active: state.position == GestureHubPosition.palmSide,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PositionTile(
                          label: labels.upLabel,
                          icon: labels.upIcon,
                          active: state.position == GestureHubPosition.palmUp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PositionTile(
                          label: 'Switch',
                          icon: Icons.screen_rotation_alt_outlined,
                          active:
                              state.position == GestureHubPosition.palmVertical,
                        ),
                      ),
                    ],
                  ),
                  if (state.selectedControl == GestureHubControl.volume &&
                      state.volumeIntensity != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.volumeIntensity!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (state.selectedControl == GestureHubControl.mouse) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Fist = click',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    state.status,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_GestureHubOverlayLabels _overlayLabels(
  GestureHubControl control,
  GestureHubMouseAxis mouseAxis,
) {
  return switch (control) {
    GestureHubControl.volume => const _GestureHubOverlayLabels(
      downLabel: 'Down',
      sideLabel: 'Neutral',
      upLabel: 'Up',
      downIcon: Icons.volume_down,
      sideIcon: Icons.pan_tool_alt_outlined,
      upIcon: Icons.volume_up,
    ),
    GestureHubControl.scroll => const _GestureHubOverlayLabels(
      downLabel: 'Down',
      sideLabel: 'Stop',
      upLabel: 'Up',
      downIcon: Icons.keyboard_arrow_down,
      sideIcon: Icons.pan_tool_alt_outlined,
      upIcon: Icons.keyboard_arrow_up,
    ),
    GestureHubControl.mouse =>
      mouseAxis == GestureHubMouseAxis.vertical
          ? const _GestureHubOverlayLabels(
              downLabel: 'Down',
              sideLabel: 'Axis',
              upLabel: 'Up',
              downIcon: Icons.keyboard_arrow_down,
              sideIcon: Icons.swap_horiz,
              upIcon: Icons.keyboard_arrow_up,
            )
          : const _GestureHubOverlayLabels(
              downLabel: 'Right',
              sideLabel: 'Axis',
              upLabel: 'Left',
              downIcon: Icons.keyboard_arrow_right,
              sideIcon: Icons.swap_horiz,
              upIcon: Icons.keyboard_arrow_left,
            ),
  };
}

String _mouseAxisLabel(GestureHubMouseAxis axis) {
  return switch (axis) {
    GestureHubMouseAxis.vertical => 'Vertical',
    GestureHubMouseAxis.horizontal => 'Horizontal',
  };
}

class _GestureHubOverlayLabels {
  const _GestureHubOverlayLabels({
    required this.downLabel,
    required this.sideLabel,
    required this.upLabel,
    required this.downIcon,
    required this.sideIcon,
    required this.upIcon,
  });

  final String downLabel;
  final String sideLabel;
  final String upLabel;
  final IconData downIcon;
  final IconData sideIcon;
  final IconData upIcon;
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.label,
    required this.icon,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 72,
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
