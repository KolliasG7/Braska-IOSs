import 'package:braska/providers/connection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connect rejects clearly invalid host input immediately', () async {
    final cp = ConnectionProvider();

    await cp.connect('not a host:::');

    expect(cp.connState, ConnState.error);
    expect(cp.error, isNotNull);
    expect(cp.error, contains('Invalid host or URL'));
  });

  test('connect accepts normalized host-like inputs and proceeds past validation', () async {
    final cp = ConnectionProvider();

    // This should normalize and then attempt network; we only verify
    // it is not rejected by local validation path.
    await cp.connect('192.168.1.116:8765/');

    expect(cp.error, isNot(contains('Invalid host or URL')));
  });
}
