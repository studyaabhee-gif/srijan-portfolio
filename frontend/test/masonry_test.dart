import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srijan_portfolio/widgets/sections/gallery_section.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<double> heights) async {
    tester.view.physicalSize = const Size(330, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: MasonryLayout(columns: 3, gap: 15, children: [
          for (var i = 0; i < heights.length; i++) SizedBox(key: ValueKey(i), height: heights[i]),
        ]),
      ),
    ));
  }

  Offset at(WidgetTester t, int i) => t.getTopLeft(find.byKey(ValueKey(i)));

  testWidgets('each tile goes into the shortest column', (tester) async {
    // Column width = (330 - 2*15) / 3 = 100.
    await pump(tester, [300, 100, 100, 100, 100]);
    expect(at(tester, 0), const Offset(0, 0));
    expect(at(tester, 1), const Offset(115, 0));
    expect(at(tester, 2), const Offset(230, 0));
    // Round-robin would put tile 3 under the 300px tile; masonry fills the short columns.
    expect(at(tester, 3), const Offset(115, 115));
    expect(at(tester, 4), const Offset(230, 115));
    expect(tester.getSize(find.byType(MasonryLayout)).height, 300);
    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 100);
  });

  testWidgets('re-balances when a tile changes height (photo finished loading)', (tester) async {
    await pump(tester, [100, 100, 100, 100]);
    expect(at(tester, 3), const Offset(0, 115));
    await pump(tester, [100, 400, 100, 100]);
    expect(at(tester, 3), const Offset(0, 115));
    await pump(tester, [400, 100, 100, 100]);
    expect(at(tester, 3), const Offset(115, 115));
  });
}
