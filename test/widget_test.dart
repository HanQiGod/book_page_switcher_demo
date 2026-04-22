import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_page_switcher_demo/main.dart';

void main() {
  testWidgets('renders book page switcher demo', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('仿真卷页阅读器'), findsOneWidget);
    expect(find.text('阅读器演示'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('下一页'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('上一页'), findsOneWidget);
    expect(find.text('下一页'), findsOneWidget);

    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
  });
}
