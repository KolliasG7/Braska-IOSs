import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:braska/main.dart';
import 'package:braska/providers/connection_provider.dart';

void main() {
  testWidgets('connect screen has no mojibake marker', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConnectionProvider(),
        child: const StrawberryManagerApp(),
      ),
    );

    await tester.pump();

    // Guard against UTF-8/encoding regressions like "Â·" rendering artifacts.
    expect(find.textContaining('Â'), findsNothing);
  });
}
