import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../models/publication.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../common/actions.dart';
import '../common/layout.dart';

/// Categories shown first, in this order; any others in the data follow.
const primaryCategories = [
  'Environmetrics & Air Quality',
  'Environmental Epidemiology',
  'Climate & Public Health',
  'HDI & Socio-Economic Modeling',
  'Statistical Methodology & GLM',
  'Time Series & Distributed Lag',
];

class ResearchSection extends ConsumerWidget {
  const ResearchSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    final cols = switch (size) {
      ScreenSize.mobile => 1,
      ScreenSize.tablet => 2,
      _ => 3,
    };
    return SectionShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          eyebrow: 'Research & Publications',
          title: 'Statistics in service of environment and health',
          subtitle: 'Five research pillars spanning environmetrics, epidemiology, climate and hydrology, '
              'human development measurement and theoretical statistics.',
        ),
        AsyncBlock(
          value: ref.watch(profileProvider),
          minHeight: 200,
          builder: (p) => ResponsiveGrid(
            columns: cols,
            children: [for (final (i, r) in p.researchPillars.indexed) _PillarCard(index: i + 1, pillar: r)],
          ),
        ),
        const SizedBox(height: 72),
        Text('Publications explorer', style: context.text.headlineMedium),
        const SizedBox(height: 8),
        Text('Search titles, co-authors, journals and keywords. Filter by theme, sort by impact or date.',
            style: context.text.bodyMedium),
        const SizedBox(height: 24),
        const _PublicationExplorer(),
      ]),
    );
  }
}

class _PillarCard extends StatefulWidget {
  const _PillarCard({required this.index, required this.pillar});
  final int index;
  final ResearchPillar pillar;

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hover ? p.gold : p.border),
          boxShadow: _hover ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.index.toString().padLeft(2, '0'), style: context.mono(size: 28, weight: FontWeight.w300, color: p.gold)),
          const SizedBox(height: 12),
          Text(widget.pillar.title, style: context.text.titleLarge),
          const SizedBox(height: 10),
          Text(widget.pillar.summary, style: context.text.bodyMedium),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in widget.pillar.keywords) Pill(k, mono: true)]),
        ]),
      ),
    );
  }
}

class _PublicationExplorer extends ConsumerStatefulWidget {
  const _PublicationExplorer();

  @override
  ConsumerState<_PublicationExplorer> createState() => _PublicationExplorerState();
}

class _PublicationExplorerState extends ConsumerState<_PublicationExplorer> {
  static const _pageSize = 8;
  final _search = TextEditingController();
  Timer? _debounce;
  int _visible = _pageSize;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(publicationQueryProvider.notifier).setSearch(v);
      setState(() => _visible = _pageSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = screenSize(context);
    final query = ref.watch(publicationQueryProvider);
    final results = ref.watch(publicationsProvider);
    final all = ref.watch(allPublicationsProvider).value ?? const <Publication>[];

    final counts = <String, int>{};
    for (final pub in all) {
      counts[pub.category] = (counts[pub.category] ?? 0) + 1;
    }
    final categories = [
      'All',
      ...primaryCategories.where(counts.containsKey),
      ...(counts.keys.where((c) => !primaryCategories.contains(c)).toList()..sort()),
    ];

    final searchField = TextField(
      controller: _search,
      onChanged: _onSearch,
      decoration: InputDecoration(
        hintText: 'Search title, co-author, journal, keyword…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _search.clear();
                  _onSearch('');
                },
              ),
      ),
    );

    final sort = DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: DropdownButton<PubSort>(
          value: query.sort,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.swap_vert),
          padding: const EdgeInsets.symmetric(vertical: 4),
          items: [for (final s in PubSort.values) DropdownMenuItem(value: s, child: Text(s.label))],
          onChanged: (s) {
            if (s != null) ref.read(publicationQueryProvider.notifier).setSort(s);
          },
        ),
      ),
    );

    final items = results.value ?? const <Publication>[];
    final shown = items.take(_visible).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (size.isMobile) ...[
        searchField,
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: sort),
      ] else
        Row(children: [Expanded(child: searchField), const SizedBox(width: 12), sort]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in categories)
          ChoiceChip(
            label: Text(c == 'All' ? 'All (${all.length})' : '$c (${counts[c]})'),
            selected: query.category == c,
            showCheckmark: false,
            onSelected: (_) {
              ref.read(publicationQueryProvider.notifier).setCategory(c);
              setState(() => _visible = _pageSize);
            },
          ),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Text('${items.length} publication${items.length == 1 ? '' : 's'}', style: context.mono(size: 12, color: p.muted)),
        const SizedBox(width: 12),
        if (results.isLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 12),
      if (results.hasError && items.isEmpty)
        Text('Could not load publications.', style: context.text.bodyMedium)
      else if (items.isEmpty && !results.isLoading)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(border: Border.all(color: p.border), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(Icons.search_off, size: 32, color: p.muted),
            const SizedBox(height: 8),
            Text('No publications match these filters.', style: context.text.bodyMedium),
          ]),
        )
      else
        for (final pub in shown)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: PublicationCard(pub: pub, key: ValueKey(pub.id))),
      if (items.length > shown.length)
        Center(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _visible += _pageSize),
            icon: const Icon(Icons.expand_more),
            label: Text('Show more (${items.length - shown.length} remaining)'),
          ),
        ),
    ]);
  }
}

class PublicationCard extends StatefulWidget {
  const PublicationCard({super.key, required this.pub});
  final Publication pub;

  @override
  State<PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pub = widget.pub;
    final mobile = screenSize(context).isMobile;

    final authors = Text.rich(
      TextSpan(children: [
        for (final (i, a) in pub.authors.indexed) ...[
          if (i > 0) const TextSpan(text: ', '),
          TextSpan(
            text: a,
            style: a == 'S.L. Shrestha' ? TextStyle(fontWeight: FontWeight.w700, color: p.ink) : null,
          ),
        ],
      ]),
      style: context.text.bodyMedium,
    );

    final citeBadge = pub.citations > 0
        ? Tooltip(
            message: 'Approximate citation count (Google Scholar)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.gold.withValues(alpha: 0.35)),
              ),
              child: Column(children: [
                Text('${pub.citations}+', style: context.mono(size: 16, weight: FontWeight.w700, color: p.gold)),
                Text('citations', style: context.text.labelSmall?.copyWith(color: p.muted)),
              ]),
            ),
          )
        : null;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(mobile ? 18 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Pill(pub.dateLabel, mono: true, color: p.ink),
                  Pill(pub.category, color: p.accent),
                ]),
                const SizedBox(height: 12),
                Text(pub.title, style: context.text.titleLarge?.copyWith(fontSize: mobile ? 18 : 20)),
                const SizedBox(height: 8),
                authors,
                const SizedBox(height: 6),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(pub.journal, style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: p.ink)),
                  if (pub.sourceDetails.isNotEmpty) Text(pub.sourceDetails, style: context.mono(size: 12, color: p.muted)),
                ]),
              ]),
            ),
            if (citeBadge != null) ...[const SizedBox(width: 16), citeBadge],
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Summary', style: context.text.labelLarge?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(pub.summary, style: context.text.bodyLarge?.copyWith(fontSize: 15)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final k in pub.keywords) Pill(k, mono: true)]),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.border),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(pub.toBibtex(), style: context.mono(size: 12, weight: FontWeight.w400)),
                        ),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 4, runSpacing: 4, children: [
            TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_open ? 'Hide details' : 'Summary & BibTeX'),
            ),
            TextButton.icon(
              onPressed: () => copyToClipboard(context, pub.toBibtex(), 'BibTeX copied to clipboard'),
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Copy BibTeX'),
            ),
            TextButton.icon(
              onPressed: () => openLink(context, pub.externalUri),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(pub.url != null || pub.doi != null ? 'View source' : 'Find paper'),
            ),
            if (pub.url != null || pub.doi != null)
              TextButton.icon(
                onPressed: () => openLink(context, pub.scholarUri),
                icon: const Icon(Icons.school_outlined, size: 16),
                label: const Text('Google Scholar'),
              ),
          ]),
        ]),
      ),
    );
  }
}
