import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/metrics.dart';
import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../common/layout.dart';

/// Research domains in fixed order; colour follows the entity, never its rank.
const domainOrder = ['Environmetrics', 'Epidemiology', 'Climate Modeling', 'HDI & Socio-Economics', 'Theoretical Statistics'];

// Pre-validated categorical slots 1–5 (light / dark steps).
const _seriesLight = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), Color(0xFFE87BA4)];
const _seriesDark = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), Color(0xFFD55181)];

Color domainColor(BuildContext context, String domain) {
  final i = domainOrder.indexOf(domain);
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (i < 0) return context.palette.muted;
  return (dark ? _seriesDark : _seriesLight)[i];
}

class ImpactSection extends ConsumerWidget {
  const ImpactSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    final profile = ref.watch(profileProvider).value;
    return SectionShell(
      child: AsyncBlock(
        value: ref.watch(metricsProvider),
        builder: (m) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            eyebrow: 'Statistical Impact',
            title: 'Research impact in numbers',
            subtitle: 'Output, citations and thematic reach across two decades of work at Tribhuvan University.',
          ),
          _MetricTiles(m: m),
          const SizedBox(height: 12),
          Text(m.note, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
          const SizedBox(height: 32),
          if (size.isCompact) ...[
            _TrajectoryCard(m: m),
            const SizedBox(height: 20),
            _DomainCard(m: m),
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _TrajectoryCard(m: m)),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _DomainCard(m: m)),
            ]),
          if (profile != null && profile.collaborators.isNotEmpty) ...[
            const SizedBox(height: 20),
            _NetworkCard(collaborators: profile.collaborators),
          ],
        ]),
      ),
    );
  }
}

class _MetricTiles extends StatelessWidget {
  const _MetricTiles({required this.m});
  final Metrics m;

  @override
  Widget build(BuildContext context) {
    String opt(int? v) => v == null ? '—' : '$v';
    final tiles = [
      ('${m.reportedCitations}+', 'Citations', 'Reported, all works'),
      ('${m.totalPublications}', 'Publications', 'Listed on this site'),
      ('${m.hIndex}*', 'h-index', 'From listed citations'),
      ('${m.i10Index}*', 'i10-index', 'From listed citations'),
      ('${m.yearsOfService}+', 'Years at TU', 'Teaching & research'),
      ('${m.coAuthors}+', 'Co-authors', 'National & international'),
      (opt(m.phdSupervised), 'PhD theses supervised', m.phdSupervised == null ? 'Add in portfolio_seed.json' : 'Completed'),
      (opt(m.mscSupervised), 'MSc theses supervised', m.mscSupervised == null ? 'Add in portfolio_seed.json' : 'Completed'),
    ];
    final cols = switch (screenSize(context)) {
      ScreenSize.mobile => 2,
      ScreenSize.tablet => 4,
      _ => 4,
    };
    return ResponsiveGrid(
      columns: cols,
      gap: 14,
      children: [for (final t in tiles) _Tile(value: t.$1, label: t.$2, foot: t.$3)],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.foot});
  final String value, label, foot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: context.mono(size: 30, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text(label, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(foot, style: context.text.labelSmall?.copyWith(color: p.muted)),
        ]),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.caption, required this.child, this.action});
  final String title, caption;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [Text(title, style: context.text.titleLarge), ?action],
          ),
          const SizedBox(height: 4),
          Text(caption, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
          const SizedBox(height: 20),
          child,
        ]),
      ),
    );
  }
}

class _TrajectoryCard extends StatefulWidget {
  const _TrajectoryCard({required this.m});
  final Metrics m;

  @override
  State<_TrajectoryCard> createState() => _TrajectoryCardState();
}

class _TrajectoryCardState extends State<_TrajectoryCard> {
  bool _citations = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = widget.m.byYear;
    final axisStyle = context.mono(size: 10, weight: FontWeight.w400, color: p.muted);
    final grid = FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1),
    );
    Widget bottom(double v, TitleMeta meta) {
      final y = v.toInt();
      final show = y % 4 == 0 || y == data.last.year;
      return SideTitleWidget(meta: meta, child: Text(show ? "'${(y % 100).toString().padLeft(2, '0')}" : '', style: axisStyle));
    }

    Widget left(double v, TitleMeta meta) =>
        SideTitleWidget(meta: meta, child: Text(v == v.roundToDouble() ? v.toInt().toString() : '', style: axisStyle));
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    final tooltipBg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263149) : Brand.slate;
    const tipStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600);

    final maxPubs = data.map((e) => e.publications).fold(0, math.max);
    final maxCum = data.isEmpty ? 0 : data.last.cumulativeCitations;

    final chart = _citations
        ? LineChart(LineChartData(
            minX: data.first.year.toDouble(),
            maxX: data.last.year.toDouble(),
            minY: 0,
            maxY: (maxCum * 1.1).ceilToDouble(),
            gridData: grid,
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: hidden,
              rightTitles: hidden,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 26, getTitlesWidget: bottom)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 100, getTitlesWidget: left)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => tooltipBg,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem('${s.x.toInt()}\n${s.y.toInt()} cumulative citations', tipStyle),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final d in data) FlSpot(d.year.toDouble(), d.cumulativeCitations.toDouble())],
                color: p.accent,
                barWidth: 2,
                isStepLineChart: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: p.accent.withValues(alpha: 0.10)),
              ),
            ],
          ))
        : BarChart(BarChartData(
            maxY: (maxPubs + 1).toDouble(),
            gridData: grid,
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: hidden,
              rightTitles: hidden,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: bottom)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: left)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => tooltipBg,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${group.x}\n${rod.toY.toInt()} publication${rod.toY == 1 ? '' : 's'}',
                  tipStyle,
                ),
              ),
            ),
            barGroups: [
              for (final d in data)
                BarChartGroupData(x: d.year, barRods: [
                  // Zero-height rods still paint their rounded caps as dots.
                  if (d.publications > 0)
                    BarChartRodData(
                    toY: d.publications.toDouble(),
                    width: 9,
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ));

    return _ChartCard(
      title: 'Research trajectory, 2004–2026',
      caption: _citations
          ? 'Cumulative citations of the listed papers, plotted by year of publication.'
          : 'Peer-reviewed publications per year (dated works on this site).',
      action: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Output'), icon: Icon(Icons.bar_chart, size: 16)),
          ButtonSegment(value: true, label: Text('Citations'), icon: Icon(Icons.show_chart, size: 16)),
        ],
        selected: {_citations},
        onSelectionChanged: (s) => setState(() => _citations = s.first),
      ),
      child: SizedBox(height: 260, child: chart),
    );
  }
}

class _DomainCard extends StatefulWidget {
  const _DomainCard({required this.m});
  final Metrics m;

  @override
  State<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<_DomainCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final domains = [
      for (final d in domainOrder)
        if (widget.m.byDomain.any((c) => c.label == d)) widget.m.byDomain.firstWhere((c) => c.label == d),
    ];
    final total = domains.fold(0, (s, c) => s + c.count);
    final focus = _touched != null && _touched! < domains.length ? domains[_touched!] : null;

    return _ChartCard(
      title: 'Thematic distribution',
      caption: 'Share of listed publications by research domain.',
      child: Column(children: [
        SizedBox(
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 58,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, res) {
                  final i = res?.touchedSection?.touchedSectionIndex;
                  if (!event.isInterestedForInteractions || i == null || i < 0) {
                    if (_touched != null) setState(() => _touched = null);
                  } else if (i != _touched) {
                    setState(() => _touched = i);
                  }
                },
              ),
              sections: [
                for (final (i, d) in domains.indexed)
                  PieChartSectionData(
                    value: d.count.toDouble(),
                    color: domainColor(context, d.label),
                    radius: i == _touched ? 38 : 32,
                    showTitle: false,
                    borderSide: BorderSide(color: p.surface, width: 2),
                  ),
              ],
            )),
            IgnorePointer(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${focus?.count ?? total}', style: context.mono(size: 26, weight: FontWeight.w700)),
                SizedBox(
                  width: 100,
                  child: Text(focus?.label ?? 'papers', textAlign: TextAlign.center, maxLines: 2,
                      style: context.text.labelSmall?.copyWith(color: p.muted)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        for (final (i, d) in domains.indexed)
          MouseRegion(
            onEnter: (_) => setState(() => _touched = i),
            onExit: (_) => setState(() => _touched = null),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: i == _touched ? p.surfaceAlt : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: domainColor(context, d.label), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Text(d.label, style: context.text.bodyMedium?.copyWith(color: p.ink))),
                Text('${d.count}', style: context.mono(size: 12, weight: FontWeight.w700)),
                SizedBox(
                  width: 48,
                  child: Text('${(d.count * 100 / math.max(total, 1)).round()}%',
                      textAlign: TextAlign.right, style: context.mono(size: 12, color: p.muted)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _NetworkCard extends StatefulWidget {
  const _NetworkCard({required this.collaborators});
  final List<Collaborator> collaborators;

  @override
  State<_NetworkCard> createState() => _NetworkCardState();
}

class _NetworkCardState extends State<_NetworkCard> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hub = widget.collaborators.firstWhere((c) => c.hub, orElse: () => widget.collaborators.first);
    final spokes = widget.collaborators.where((c) => c != hub).toList();
    final mobile = screenSize(context).isMobile;

    final graph = SizedBox(
      height: mobile ? 300 : 340,
      child: LayoutBuilder(builder: (context, c) {
        final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
        final r = math.min(c.maxWidth, c.maxHeight) / 2 - 46;
        final pos = [
          for (var i = 0; i < spokes.length; i++)
            center + Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / spokes.length, r),
        ];
        return Stack(children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgePainter(center: center, nodes: pos, highlight: _hover, base: p.border, accent: p.gold),
            ),
          ),
          _node(context, center, hub, hubNode: true),
          for (var i = 0; i < spokes.length; i++) _node(context, pos[i], spokes[i], index: i),
        ]);
      }),
    );

    final legend = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, s) in spokes.indexed)
        MouseRegion(
          onEnter: (_) => setState(() => _hover = i),
          onExit: (_) => setState(() => _hover = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: i == _hover ? p.surfaceAlt : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: i == _hover ? p.gold : p.border),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(s.kind, style: context.text.labelSmall?.copyWith(color: p.muted)),
                ]),
              ),
              Text(s.country, style: context.mono(size: 11, color: p.muted)),
            ]),
          ),
        ),
    ]);

    return _ChartCard(
      title: 'Global collaborator network',
      caption: 'Institutional co-authorships and research partnerships, centred on Tribhuvan University.',
      child: mobile
          ? Column(children: [graph, const SizedBox(height: 16), legend])
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 3, child: graph),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: legend),
            ]),
    );
  }

  Widget _node(BuildContext context, Offset at, Collaborator c, {bool hubNode = false, int? index}) {
    final p = context.palette;
    final on = hubNode || index == _hover;
    final d = hubNode ? 76.0 : 58.0;
    return Positioned(
      left: at.dx - d / 2,
      top: at.dy - d / 2,
      child: MouseRegion(
        onEnter: index == null ? null : (_) => setState(() => _hover = index),
        onExit: index == null ? null : (_) => setState(() => _hover = null),
        child: Tooltip(
          message: '${c.name}\n${c.kind} · ${c.country}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: d,
            height: d,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hubNode ? Brand.navy : (on ? p.gold : p.surface),
              border: Border.all(color: hubNode ? Brand.gold : (on ? p.gold : p.border), width: 1.5),
              boxShadow: on ? [BoxShadow(color: p.gold.withValues(alpha: 0.35), blurRadius: 16)] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                c.short,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hubNode ? Brand.goldLight : (on ? Brand.navy : p.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.center, required this.nodes, required this.highlight, required this.base, required this.accent});

  final Offset center;
  final List<Offset> nodes;
  final int? highlight;
  final Color base, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = base
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (nodes.isNotEmpty) canvas.drawCircle(center, (nodes.first - center).distance, ring);
    for (var i = 0; i < nodes.length; i++) {
      final on = i == highlight;
      canvas.drawLine(
        center,
        nodes[i],
        Paint()
          ..color = on ? accent : base
          ..strokeWidth = on ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.highlight != highlight || old.center != center || old.base != base || old.nodes.length != nodes.length;
}
