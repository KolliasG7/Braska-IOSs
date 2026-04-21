// lib/main.dart — Strawberry Manager by rmux
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final cp = context.watch<ConnectionProvider>();

    if (cp.connState == ConnState.idle && cp.rawInput.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cp.connect(cp.rawInput));
    }

    return AnimatedSwitcher(
      duration: AppDurations.med,
      reverseDuration: AppDurations.fast,
      switchInCurve:  AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      // Stack the incoming on top of the outgoing so the fade-through
      // doesn't show the gradient flickering underneath both.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
          child: child)),
      child: switch (cp.connState) {
        ConnState.connected =>
          const DashboardScreen(key: ValueKey('dash')),
        // needsAuth shows ConnectScreen which handles the password dialog
        _ => const ConnectScreen(key: ValueKey('connect')),
      },
    );
  }
}
