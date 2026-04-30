// lib/main.dart — Strawberry Manager by rmux
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'services/notification_service.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                  Colors.transparent,
    statusBarBrightness:             Brightness.dark,
    statusBarIconBrightness:         Brightness.light,
    systemNavigationBarColor:        Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.init();

  final cp = ConnectionProvider();
  await cp.loadSaved();
  runApp(ChangeNotifierProvider.value(value: cp, child: const StrawberryManagerApp()));
}

class StrawberryManagerApp extends StatelessWidget {
  const StrawberryManagerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:                      'Strawberry Manager',
    debugShowCheckedModeBanner: false,
    theme:                      buildTheme(),
    home:                       const _Root(),
  );
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final cp = context.read<ConnectionProvider>();
    final connState = context.select<ConnectionProvider, ConnState>(
      (cp) => cp.connState,
    );
    final rawInput = context.select<ConnectionProvider, String>(
      (cp) => cp.rawInput,
    );

    if (connState == ConnState.idle && rawInput.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cp.connect(cp.rawInput));
    }

    // Zoom-through between Connect and Dashboard: incoming fades in while
    // scaling up from 0.96, outgoing fades out while scaling up slightly
    // past 1 (0 → 1.04) so the departing screen reads as receding into the
    // background instead of vanishing.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve:  AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, anim) {
        final curved = CurvedAnimation(parent: anim, curve: AppCurves.emphasized);
        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
        final slide = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: AnimatedBuilder(
                animation: anim,
                builder: (_, __) {
                  final blur = (1.0 - anim.value) * 8;
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: child,
                  );
                },
              ),
            ),
          ),
        );
      },
      child: switch (connState) {
        ConnState.connected =>
          const DashboardScreen(key: ValueKey('dash')),
        // needsAuth shows ConnectScreen which handles the password dialog
        _ => const ConnectScreen(key: ValueKey('connect')),
      },
    );
  }
}
