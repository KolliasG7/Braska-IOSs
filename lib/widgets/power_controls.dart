// lib/widgets/power_controls.dart — PS4 power management
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class PowerControlsCard extends StatefulWidget {
  const PowerControlsCard({super.key, required this.api});
  final ApiService api;
  @override State<PowerControlsCard> createState() => _PowerControlsCardState();
}

class _PowerControlsCardState extends State<PowerControlsCard> {
  bool _busy = false;
  String? _err;

  Future<void> _exec(String action) async {
    final confirmed = await _confirm(action);
    if (!confirmed || !mounted) return;

    setState(() { _busy = true; _err = null; });
    try {
      await widget.api.powerAction(action);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _busy = false; });
    }
  }

  Future<bool> _confirm(String action) async {
    final label = switch (action) {
      'shutdown' => 'SHUT DOWN',
      'reboot'   => 'REBOOT',
      'suspend'  => 'SUSPEND',
      _          => action.toUpperCase(),
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Bk.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Bk.border)),
        title: Text(label,
          style: const TextStyle(
            color: Bk.textPri, fontSize: 16,
            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        content: Text(
          'Send $label command to the PS4?',
          style: const TextStyle(color: Bk.textSec, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL',
              style: TextStyle(color: Bk.textDim, letterSpacing: 1.5))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label,
              style: const TextStyle(
                color: Bk.white, fontWeight: FontWeight.w900,
                letterSpacing: 1.5))),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const StatLabel('POWER'),
              if (_busy)
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Bk.white)),
            ],
          ),
          const SizedBox(height: 14),

          // 3 power buttons in a row, uniform size
          Row(children: [
            Expanded(child: _PowerBtn(
              icon: Icons.power_off_outlined,
              label: 'SHUTDOWN',
              onTap: _busy ? null : () => _exec('shutdown'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PowerBtn(
              icon: Icons.refresh_outlined,
              label: 'REBOOT',
              onTap: _busy ? null : () => _exec('reboot'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _PowerBtn(
              icon: Icons.bedtime_outlined,
              label: 'SLEEP',
              onTap: _busy ? null : () => _exec('suspend'),
            )),
          ]),

          if (_err != null) ...[
            const SizedBox(height: 10),
            Text('✗ $_err',
              style: const TextStyle(color: Bk.danger, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _PowerBtn extends StatelessWidget {
  const _PowerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Bk.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Bk.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
              color: onTap == null ? Bk.textDim : Bk.white,
              size: 22),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(
                color: onTap == null ? Bk.textDim : Bk.textSec,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
