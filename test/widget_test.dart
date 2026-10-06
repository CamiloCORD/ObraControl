import 'package:flutter_test/flutter_test.dart';
import 'package:control_gas_app/main.dart';

void main() {
  testWidgets('Prueba de carga de la app', (WidgetTester tester) async {
    await tester.pumpWidget(const ControlGasApp());
  });
}