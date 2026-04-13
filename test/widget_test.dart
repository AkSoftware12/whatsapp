import 'package:flutter_test/flutter_test.dart';
import 'package:whatspp/main.dart';

void main() {
  testWidgets('renders status saver shell', (tester) async {
    await tester.pumpWidget(const StatusSaverApp());

    expect(find.text('WhatsApp Status Saver'), findsOneWidget);
    expect(find.text('Folder Access'), findsOneWidget);
  });
}
