import 'package:flutter_test/flutter_test.dart';
import 'package:petpal/main.dart';

void main() {
  testWidgets('PetPal 应用启动测试', (WidgetTester tester) async {
    // 验证应用可以无报错启动
    await tester.pumpWidget(const PetPalApp());
    expect(find.text('PetPal'), findsOneWidget);
  });

  testWidgets('悬浮窗渲染测试', (WidgetTester tester) async {
    await tester.pumpWidget(const PetPalApp());
    // 验证宠物悬浮窗正常渲染
    await tester.pumpAndSettle();
  });
}
