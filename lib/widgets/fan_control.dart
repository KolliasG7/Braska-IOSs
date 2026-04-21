// lib/widgets/fan_control.dart — Strawberry Manager fan threshold
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class FanControlCard extends StatefulWidget {
  const FanControlCard({super.key, required this.api, required this.currentThreshold});
  final ApiService api;
  final int currentThreshold;
  @override State<FanControlCard> createState() => _FanControlCardState();
}

class _FanControlCardState extends State<FanControlCard>
    with SingleTickerProviderStateMixin {
  static const _min = 30.0, _max = 85.0;
  late double _val;
  double? _lastCommittedValue;
  bool _writing = false;
  int? _confirmed;
  String? _err;
  late AnimationController _pulse;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _val = widget.currentThreshold.toDouble().clamp(_min, _max);
    _pulse = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FanControlCard o) {
    super.didUpdateWidget(o);
    final incoming = widget.currentThreshold.toDouble().clamp(_min, _max);
    // Keep local slider synced to telemetry updates unless user is writing.
    if (!_writing && (_lastCommittedValue == null || (incoming - _lastCommittedValue!).abs() >= 1)) {
      setState(() {
        _val = incoming;
        _confirmed = incoming.round();
      });
    }
  }

  Future<void> _commit(double v) async {
    final t = v.round();
    final req = ++_requestId;
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
    setState(() => _val = next);
    _commit(next);
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = _val.round();
    final pct  = (_val - _min) / (_max - _min);
    // Color shifts warm → hot as threshold rises
    final tColor = displayVal >= 80 ? Bk.red
                 : displayVal >= 70 ? Bk.amber : Bk.cyan;

    return GlassCard(
      tint: tColor.withOpacity(0.06),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const StatLabel('FAN THRESHOLD'),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Text('$displayVal',
                style: TextStyle(
                  color: tColor, fontSize: 36,
                  fontWeight: FontWeight.w900, letterSpacing: -1,
                )),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('°C', style: TextStyle(
                color: tColor.withOpacity(0.6), fontSize: 14,
                fontWeight: FontWeight.w700)),
            ),
            if (_writing) ...[
              const SizedBox(width: 12),
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: tColor)),
            ],
          ]),
        ]),
        const SizedBox(height: 16),

        Row(
          children: [
            _StepBtn(
              icon: Icons.remove,
              label: 'Decrease threshold',
              onTap: _writing ? null : () => _nudge(-1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor:   tColor,
                  inactiveTrackColor: Bk.border,
                  thumbColor:         Colors.white,
                  overlayColor:       tColor.withOpacity(0.12),
                  trackHeight:        4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: _val, min: _min, max: _max, divisions: 55,
                  onChanged: _writing ? null : (v) => setState(() => _val = v),
                  onChangeEnd: _writing ? null : _commit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepBtn(
              icon: Icons.add,
              label: 'Increase threshold',
              onTap: _writing ? null : () => _nudge(1),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_min.round()}°C',
              style: const TextStyle(color: Bk.textDim, fontSize: 10)),
            Text('${_max.round()}°C',
              style: const TextStyle(color: Bk.textDim, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 10),

        // Status
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _confirmed != null && !_writing
            ? Text('✓ Hardware confirmed: $_confirmed°C',
                key: const ValueKey('ok'),
                style: const TextStyle(color: Bk.green, fontSize: 11))
            : _err != null
              ? Text('✗ $_err',
                  key: const ValueKey('err'),
                  style: const TextStyle(color: Bk.red, fontSize: 11))
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
        const SizedBox(height: 6),
        const Text('Release slider to apply · kernel RMW cycle',
          style: TextStyle(color: Bk.textDim, fontSize: 10)),
      ]),
    );
  }

  @override void dispose() { _pulse.dispose(); super.dispose(); }
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
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Bk.surface1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Bk.border),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? Bk.textDim : Bk.white,
          ),
        ),
      ),
    );
  }
}
