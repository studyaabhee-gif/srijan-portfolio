import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../screens/sections.dart';
import '../../theme/app_theme.dart';
import '../common/actions.dart';
import '../common/layout.dart';
import '../nav_bar.dart';

IconData linkIcon(String kind) => switch (kind) {
      'scholar' => Icons.school_outlined,
      'researchgate' => Icons.science_outlined,
      'orcid' => Icons.fingerprint,
      'linkedin' => Icons.work_outline,
      'sciprofiles' => Icons.badge_outlined,
      'journal' => Icons.menu_book_outlined,
      'institution' => Icons.account_balance_outlined,
      'ranking' => Icons.leaderboard_outlined,
      _ => Icons.link,
    };

class HeroSection extends ConsumerWidget {
  const HeroSection({super.key, required this.onNavigate});

  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.7, -0.6),
          radius: 1.2,
          colors: [context.palette.gold.withValues(alpha: 0.10), context.palette.background],
        ),
      ),
      child: SectionShell(
        top: kNavHeight + (size.isMobile ? 48 : 72),
        bottom: size.isMobile ? 64 : 96,
        child: AsyncBlock(
          value: ref.watch(profileProvider),
          minHeight: 520,
          builder: (p) => size.isCompact
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Intro(profile: p, onNavigate: onNavigate),
                  const SizedBox(height: 48),
                  _Portrait(profile: p, floating: false),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 6, child: _Intro(profile: p, onNavigate: onNavigate)),
                  const SizedBox(width: 72),
                  Expanded(flex: 5, child: _Portrait(profile: p, floating: true)),
                ]),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.profile, required this.onNavigate});

  final Profile profile;
  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = screenSize(context);
    final quick = ['scholar', 'researchgate', 'orcid', 'linkedin'].map(profile.link).whereType<LinkItem>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, b) in profile.badges.indexed)
          Pill(b, color: [p.ink, p.accent, p.gold][i % 3], icon: [Icons.account_balance, Icons.edit_note, Icons.history_edu][i % 3]),
      ]),
      const SizedBox(height: 28),
      Text(profile.name, style: size.isMobile ? context.text.displaySmall : context.text.displayMedium),
      const SizedBox(height: 14),
      Text(profile.headline,
          style: context.text.headlineSmall?.copyWith(fontStyle: FontStyle.italic, color: p.accent, fontWeight: FontWeight.w500)),
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final para in profile.bio.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(para, style: context.text.bodyLarge?.copyWith(color: p.muted)),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.icon(
          onPressed: () => onNavigate(Section.research),
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text('Explore publications'),
        ),
        OutlinedButton.icon(
          onPressed: () => onNavigate(Section.contact),
          icon: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Contact & supervision'),
        ),
      ]),
      const SizedBox(height: 28),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in quick)
          ActionChip(
            avatar: Icon(linkIcon(l.kind), size: 16, color: p.ink),
            label: Text(l.label),
            tooltip: l.handle != null ? 'ORCID iD ${l.handle}' : l.url,
            onPressed: () => openLink(context, Uri.parse(l.url)),
          ),
      ]),
    ]);
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.profile, required this.floating});

  final Profile profile;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          left: 18,
          top: 18,
          right: -18,
          bottom: -18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: p.gold, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              profile.portrait,
              fit: BoxFit.cover,
              // Bias the crop upward so the face stays in the 4:5 frame.
              alignment: const Alignment(0, -0.6),
              semanticLabel: 'Portrait of ${profile.name}',
              errorBuilder: (c, e, s) => const _MonogramFallback(),
            ),
          ),
        ),
      ]),
    );

    final kpis = profile.kpis;
    if (!floating) {
      return Column(children: [
        Padding(padding: const EdgeInsets.only(right: 18, bottom: 18), child: frame),
        const SizedBox(height: 24),
        ResponsiveGrid(
          columns: 2,
          gap: 12,
          children: [for (final k in kpis) _KpiCard(kpi: k)],
        ),
      ]);
    }

    // Desktop: KPI cards float around the framed portrait.
    const spots = [
      (left: -56.0, top: 48.0, right: null, bottom: null),
      (left: null, top: 120.0, right: -40.0, bottom: null),
      (left: -40.0, top: null, right: null, bottom: 120.0),
      (left: null, top: null, right: -56.0, bottom: 28.0),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Stack(clipBehavior: Clip.none, children: [
          frame,
          for (var i = 0; i < kpis.length && i < spots.length; i++)
            Positioned(
              left: spots[i].left,
              top: spots[i].top,
              right: spots[i].right,
              bottom: spots[i].bottom,
              child: _KpiCard(kpi: kpis[i], floating: true),
            ),
        ]),
      ),
    );
  }
}

class _MonogramFallback extends StatelessWidget {
  const _MonogramFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.navy, Brand.slate]),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('SLS', style: context.text.displayLarge?.copyWith(color: Brand.goldLight)),
        const SizedBox(height: 12),
        Text('Add portrait at\nfrontend/assets/images/profile/hero_portrait.jpg',
            textAlign: TextAlign.center, style: context.mono(size: 11, color: const Color(0xFF9CA6BA))),
      ]),
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.kpi, this.floating = false});

  final Kpi kpi;
  final bool floating;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final long = widget.kpi.value.length > 6;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: _hover ? const Offset(0, -0.04) : Offset.zero,
        child: Container(
          constraints: widget.floating ? const BoxConstraints(maxWidth: 190) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: widget.floating ? 0.94 : 1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? p.gold : p.border),
            boxShadow: widget.floating
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))]
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.kpi.value,
                style: long
                    ? context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: p.accent)
                    : context.mono(size: 24, weight: FontWeight.w700, color: p.accent)),
            const SizedBox(height: 2),
            Text(widget.kpi.label, style: context.text.labelMedium?.copyWith(color: p.muted)),
          ]),
        ),
      ),
    );
  }
}
