import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srijan_portfolio/widgets/common/layout.dart';

Widget _cell(Key key, int words) => Container(
      key: key,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(List.filled(words, 'word').join(' ')),
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [for (var i = 0; i < words ~/ 4; i++) Chip(label: Text('tag $i'))]),
      ]),
    );

void main() {
  testWidgets('cells share the tallest height and never overflow', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const a = Key('a'), b = Key('b'), c = Key('c'), d = Key('d');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResponsiveGrid(columns: 3, children: [_cell(a, 4), _cell(b, 60), _cell(c, 12), _cell(d, 8)]),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final hb = tester.getSize(find.byKey(b)).height;
    expect(tester.getSize(find.byKey(a)).height, hb);
    expect(tester.getSize(find.byKey(c)).height, hb);
    expect(tester.getSize(find.byKey(d)).height, lessThan(hb));
    expect(tester.getSize(find.byKey(a)).width, closeTo((900 - 40) / 3, 0.01));

    await tester.tap(find.text('tag 0').first);
  });

  testWidgets('a cell that grows after layout (late font) grows the row instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final extra = ValueNotifier(0.0);
    addTearDown(extra.dispose);
    const a = Key('a'), b = Key('b');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResponsiveGrid(columns: 2, children: [
            Column(key: a, children: [
              const SizedBox(height: 100),
              // Changes size without rebuilding the grid, like a font arriving.
              ValueListenableBuilder<double>(
                valueListenable: extra,
                builder: (_, h, _) => SizedBox(height: h),
              ),
            ]),
            const SizedBox(key: b, height: 80),
          ]),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(b)).height, 100);

    extra.value = 40;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(a)).height, 140);
    expect(tester.getSize(find.byKey(b)).height, 140);
  });
}
