// lib/widgets/gpu_control.dart — GPU SCLK level control.
import 'package:flutter/material.dart';
import '../models/gpu.dart';
import '../services/api_service.dart';
import '../theme.dart';

class GpuControlCard extends StatefulWidget {
  const GpuControlCard({super.key, required this.api});
  final ApiService api;
  @override State<GpuControlCard> createState() => _GpuControlCardState();
}

class _GpuControlCardState extends State<GpuControlCard> {
  GpuState? _state;
  bool _loading = true;
  bool _writing = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final caps = await widget.api.getCapabilities();
      if (!mounted) return;

      final gpuData = caps['gpu'] as Map<String, dynamic>?;
      if (gpuData == null) {
        setState(() {
          _loading = false;
          _state = const GpuState(
            available: false,
            supportedHardware: false,
            hasActiveLevel: false,
          );
        });
        return;
      }

      // For now, we'll use the capabilities data
      // In a full implementation, we'd need a dedicated /api/gpu/status endpoint
      setState(() {
        _loading = false;
        _state = GpuState(
          available: gpuData['available'] as bool? ?? false,
          supportedHardware: gpuData['supported_hardware'] as bool? ?? false,
          performanceLevel: gpuData['performance_level'] as String?,
          hasActiveLevel: false,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  Future<void> _setManual(bool enabled) async {
    setState(() { _writing = true; _err = null; });
    try {
      await widget.api.setGpuManual(enabled);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _writing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const GlassCard(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: Bk.accent),
          ),
        ),
      );
    }

    if (_err != null) {
      return GlassCard(
        tint: Bk.danger.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.error_outline,
                  color: Bk.danger, size: 16),
              SizedBox(width: 8),
              Text('GPU CONTROL',
                style: TextStyle(
                  color: Bk.textSec, fontSize: 11, letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(_err!,
              style: const TextStyle(color: Bk.danger, fontSize: 12)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _load,
              child: const Text('Retry',
                style: TextStyle(color: Bk.accent, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final state = _state!;
    if (!state.available) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.memory_outlined,
                  color: Bk.textDim, size: 16),
              SizedBox(width: 8),
              Text('GPU CONTROL',
                style: TextStyle(
                  color: Bk.textSec, fontSize: 11, letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(
              state.supportedHardware
                  ? 'GPU control nodes not available'
                  : 'GPU SCLK forcing only supported on CHIP_LIVERPOOL / CHIP_GLADIUS',
              style: const TextStyle(color: Bk.textDim, fontSize: 12)),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.memory_outlined,
              color: Bk.textSec, size: 14),
          const SizedBox(width: 6),
          const Text('GPU CONTROL',
            style: TextStyle(
              color: Bk.textSec, fontSize: 11, letterSpacing: 1.2,
              fontWeight: FontWeight.w700)),
          const Spacer(),
          if (state.supportedHardware)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Bk.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: Bk.success.withValues(alpha: 0.4), width: 1),
              ),
              child: const Text('SUPPORTED',
                style: TextStyle(
                  color: Bk.success, fontSize: 10,
                  fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        // Manual mode toggle
        _ModeToggle(
          isManual: state.isManual,
          writing: _writing,
          onToggle: _writing ? null : (v) => _setManual(v),
        ),

        const SizedBox(height: AppSpacing.md),

        // Info text
        const Text(
          'Manual mode allows forcing specific GPU SCLK levels for performance tuning.',
          style: TextStyle(
            color: Bk.textDim, fontSize: 11, height: 1.4),
        ),
      ]),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.isManual,
    required this.writing,
    required this.onToggle,
  });

  final bool isManual;
  final bool writing;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _ModeOption(
          label: 'Auto',
          sub: 'System managed',
          selected: !isManual,
          onTap: writing || !isManual ? null : () => onToggle!(false),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: _ModeOption(
          label: 'Manual',
          sub: 'Force SCLK level',
          selected: isManual,
          onTap: writing || isManual ? null : () => onToggle!(true),
        ),
      ),
    ]);
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.med,
        curve: AppCurves.emphasized,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? Bk.accent.withValues(alpha: 0.15)
              : Bk.glassSubtle,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected
                ? Bk.accent.withValues(alpha: 0.5)
                : Bk.glassBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: TextStyle(
                color: selected ? Bk.accent : Bk.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub,
              style: TextStyle(
                color: selected
                    ? Bk.accent.withValues(alpha: 0.8)
                    : Bk.textDim,
                fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
