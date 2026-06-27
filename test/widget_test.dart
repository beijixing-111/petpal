import 'package:flutter_test/flutter_test.dart';
import 'package:petpal/main.dart';
import 'package:petpal/providers/pet_provider.dart';
import 'package:petpal/providers/settings_provider.dart';

void main() {
  testWidgets('PetPal 应用启动测试', (WidgetTester tester) async {
    final settings = SettingsProvider();
    final petProvider = PetProvider();
    await tester.pumpWidget(PetPalApp(
      isFirstLaunch: false,
      settings: settings,
      petProvider: petProvider,
    ));
    expect(find.text('PetPal'), findsOneWidget);
  });
}
