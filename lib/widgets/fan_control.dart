// lib/widgets/fan_control.dart — Fan threshold with gradient slider.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FanControlCard extends StatefulWidget {
  const FanControlCard({super.key, required this.api, required this.currentThreshold});
  final ApiService api;
  final int currentThreshold;
  @override State<FanControlCard> createState() => _FanControlCardState();
}

class _FanControlCardState extends State<FanControlCard> {
  static const _min = 30.0, _max = 85.0;
  late double _val;
  double? _lastCommittedValue;
  bool _writing = false;
  int? _confirmed;
  String? _err;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _val = widget.currentThreshold.toDouble().clamp(_min, _max);
  }

  @override
  void didUpdateWidget(FanControlCard o) {
    super.didUpdateWidget(o);
    final incoming = widget.currentThreshold.toDouble().clamp(_min, _max);
    if (!_writing && (_lastCommittedValue == null ||
        (incoming - _lastCommittedValue!).abs() >= 1)) {
      setState(() {
        _val = incoming;
        _confirmed = incoming.round();
      });
    }
  }

  Future<void> _commit(double v) async {
    final t = v.round();
    final req = ++_requestId;
    HapticFeedback.selectionClick();
    setState(() { _writing = true; _err = null; });
    try {
      final c = await widget.api.setFanThreshold(t);
      if (!mounted || req != _requestId) return;
      setState(() {
        _confirmed = c;
        _writing = false;
        _val = c.toDouble().clamp(_min, _max);
        _lastCommittedValue = _val;
      });
    } catch (e) {
      if (!mounted || req != _requestId) return;
      setState(() {
        _err = e.toString(); _writing = false;
        _val = widget.currentThreshold.toDouble().clamp(_min, _max);
      });
    }
  }

  void _nudge(int delta) {
    if (_writing) return;
    final next = (_val + delta).clamp(_min, _max).toDouble();
    if ((next - _val).abs() < 0.01) return;
    HapticFeedback.selectionClick();
    setState(() => _val = next);
    _commit(next);
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = _val.round();
    final tColor = displayVal >= 80 ? Bk.red
                 : displayVal >= 70 ? Bk.amber : Bk.cyan;

    return GlassCard(
      tint: tColor.withOpacity(0.06),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.thermostat_outlined,
              color: Bk.textSec, size: 14),
          const SizedBox(width: 6),
          const Text('FAN THRESHOLD',
            style: TextStyle(
              color: Bk.textSec, fontSize: 11, letterSpacing: 1.2,
              fontWeight: FontWeight.w700)),
          const Spacer(),
          AnimatedSwitcher(
            duration: AppDurations.med,
            switchInCurve: AppCurves.enter,
            switchOutCurve: AppCurves.exit,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: _writing
              ? SizedBox(
                  key: const ValueKey('w'),
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: tColor))
              : _confirmed != null
                ? Row(
                    key: const ValueKey('ok'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline,
                        color: Bk.success, size: 14),
                      SizedBox(width: 4),
                      Text('Synced',
                        style: TextStyle(
                          color: Bk.success, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                    ])
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        // Big value.
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedSwitcher(
            duration: AppDurations.med,
            switchInCurve: AppCurves.enter,
            switchOutCurve: AppCurves.exit,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                child: c)),
            child: Text('$displayVal',
              key: ValueKey(displayVal),
              style: TextStyle(
                color: tColor, fontSize: 52, height: 1,
                fontWeight: FontWeight.w800, letterSpacing: -2)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('°C',
              style: TextStyle(
                color: tColor.withOpacity(0.7), fontSize: 18,
                fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          ),
        ]),

        const SizedBox(height: AppSpacing.md),

        // Slider row.
        Row(children: [
          _StepBtn(icon: Icons.remove,
            label: 'Decrease',
            onTap: _writing ? null : () => _nudge(-1)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _GradientSlider(
            value: _val, min: _min, max: _max,
            activeColor: tColor,
            enabled: !_writing,
            onChanged: (v) => setState(() => _val = v),
            onChangeEnd: _commit,
          )),
          const SizedBox(width: AppSpacing.md),
          _StepBtn(icon: Icons.add,
            label: 'Increase',
            onTap: _writing ? null : () => _nudge(1)),
        ]),

        const SizedBox(height: 10),

        // Ticks.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 46),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _Tick('30°'), _Tick('45°'),
              _Tick('60°'), _Tick('75°'), _Tick('85°'),
            ])),

        const SizedBox(height: AppSpacing.md),

        // Error or hint.
        AnimatedSwitcher(
          duration: AppDurations.med,
          switchInCurve: AppCurves.enter,
          switchOutCurve: AppCurves.exit,
          child: _err != null
            ? Text('✗ $_err',
                key: const ValueKey('err'),
                style: const TextStyle(color: Bk.danger, fontSize: 11))
            : const Text(
                'Release slider to apply · kernel RMW cycle',
                key: ValueKey('hint'),
                style: TextStyle(color: Bk.textDim, fontSize: 10)),
        ),
      ]),
    );
  }
}

// ── Gradient slider ──────────────────────────────────────────────────────

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  double _tFor(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0);

  double _valueFor(double localX, double width) {
    final t = (localX / width).clamp(0.0, 1.0);
    final raw = min + t * (max - min);
    return raw.roundToDouble().clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      const thumbR = 14.0;
      final w = box.maxWidth;
      final t = _tFor(value);
      final thumbX = t * w;

      void drag(Offset local) {
        if (!enabled) return;
        final v = _valueFor(local.dx, w);
        if ((v - value).abs() >= 1) HapticFeedback.selectionClick();
        onChanged(v);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (d) { drag(d.localPosition);
                    onChangeEnd(_valueFor(d.localPosition.dx, w)); }
            : null,
        onHorizontalDragUpdate: enabled ? (d) => drag(d.localPosition) : null,
        onHorizontalDragEnd: enabled ? (_) => onChangeEnd(value) : null,
        child: SizedBox(
          height: 40,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft,
            children: [
              // Inactive track — faint spectrum preview, very dim.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [
                      Bk.cyan.withOpacity(0.18),
                      Bk.amber.withOpacity(0.18),
                      Bk.danger.withOpacity(0.22),
                    ]),
                    border: Border.all(color: Bk.glassBorder, width: 1),
                  ),
                ),
              ),
              // Active fill — full-saturation gradient up to thumb.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: thumbX,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Bk.cyan, Bk.amber, Bk.danger,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              // Thumb.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                curve: Curves.easeOut,
                left: (thumbX - thumbR).clamp(0, w - thumbR * 2),
                child: _SliderThumb(
                  radius: thumbR,
                  color: activeColor,
                  enabled: enabled,
                ),
              ),
            ]),
        ),
      );
    });
  }
}

class _SliderThumb extends StatelessWidget {
  const _SliderThumb({
    required this.radius,
    required this.color,
    required this.enabled,
  });
  final double radius;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: enabled ? color : Bk.textDim,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
    style: const TextStyle(
      color: Bk.textDim, fontSize: 10, fontWeight: FontWeight.w600));
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.emphasized,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: disabled ? Bk.glassSubtle : Bk.glassRaised,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: disabled ? Bk.glassBorder : Bk.glassBorderHi, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(icon,
            size: 16,
            color: disabled ? Bk.textDim : Bk.textPri),
        ),
      ),
    );
  }
}
