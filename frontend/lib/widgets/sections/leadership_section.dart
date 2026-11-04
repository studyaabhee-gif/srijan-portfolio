import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../common/actions.dart';
import '../common/layout.dart';
import '../common/smart_image.dart';

class LeadershipSection extends ConsumerWidget {
  const LeadershipSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    return SectionShell(
      alt: true,
      child: AsyncBlock(
        value: ref.watch(profileProvider),
        builder: (p) {
          final timeline = _Timeline(entries: p.timeline);
          final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _AppointmentsCard(profile: p),
            const SizedBox(height: 20),
            _EditorialCard(profile: p),
          ]);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
              eyebrow: 'Academic Leadership',
              title: 'Leadership, honours & milestones',
              subtitle: 'From doctoral research at Tribhuvan University to national academic honours, '
                  'departmental leadership and editorial stewardship of the Nepalese Journal of Statistics.',
            ),
            if (size.isCompact) ...[
              timeline,
              const SizedBox(height: 32),
              side,
            ] else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 7, child: timeline),
                const SizedBox(width: 40),
                Expanded(flex: 5, child: side),
              ]),
            const SizedBox(height: 56),
            Text('Honours & recognition', style: context.text.headlineSmall),
            const SizedBox(height: 20),
            ResponsiveGrid(
              columns: size.isMobile ? 1 : 2,
              children: [for (final h in p.honors) _HonorCard(honor: h)],
            ),
          ]);
        },
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.entries});
  final List<TimelineEntry> entries;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  late int _selected = widget.entries.length - 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(children: [
      for (final (i, e) in widget.entries.indexed)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                Container(width: 2, height: 18, color: i == 0 ? Colors.transparent : p.border),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _selected ? p.accent : p.surface,
                    border: Border.all(color: i == _selected ? p.accent : p.border, width: 1.5),
                  ),
                  child: Icon(
                    switch (e.kind) {
                      'education' => Icons.school_outlined,
                      'honor' => Icons.military_tech_outlined,
                      _ => Icons.account_balance_outlined,
                    },
                    size: 18,
                    color: i == _selected ? Colors.white : p.muted,
                  ),
                ),
                Expanded(child: Container(width: 2, color: i == widget.entries.length - 1 ? Colors.transparent : p.border)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: i == _selected ? p.surface : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: i == _selected ? p.border : Colors.transparent),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selected = i),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.period.toUpperCase(),
                            style: context.mono(size: 11, weight: FontWeight.w600, color: p.gold).copyWith(letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(e.title, style: context.text.titleLarge),
                        const SizedBox(height: 2),
                        Text(e.organization, style: context.text.bodyMedium),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: Alignment.topLeft,
                          child: i == _selected
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Text(e.description, style: context.text.bodyLarge?.copyWith(fontSize: 15)),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Appointments', style: context.text.titleLarge),
          const SizedBox(height: 16),
          for (final a in profile.appointments)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: a.current ? p.accent : p.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.role, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(a.organization, style: context.text.bodyMedium),
                  ]),
                ),
                const SizedBox(width: 8),
                Pill(a.period, color: a.current ? p.accent : p.muted, mono: true),
              ]),
            ),
          const Divider(height: 24),
          for (final e in profile.education)
            Row(children: [
              Icon(Icons.school_outlined, size: 18, color: p.gold),
              const SizedBox(width: 10),
              Expanded(child: Text('${e.degree} in ${e.field}, ${e.institution}', style: context.text.bodyMedium)),
            ]),
        ]),
      ),
    );
  }
}

class _EditorialCard extends StatelessWidget {
  const _EditorialCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final board = profile.editorialBoards.isEmpty ? null : profile.editorialBoards.first;
    if (board == null) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: board.url == null ? null : () => openLink(context, Uri.parse(board.url!)),
        child: Row(children: [
          SizedBox(
            // Matches the cover's portrait shape (~0.78) so it shows uncropped.
            width: 96,
            height: 124,
            child: SmartImage(
              asset: 'assets/images/logos/njs_cover.jpg',
              dropPath: 'frontend/assets/images/logos/njs_cover.jpg',
              compact: true,
              decodeWidth: 300,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(board.role.toUpperCase(), style: context.mono(size: 11, color: p.accent, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(board.journal, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Visit on NepJOL', style: context.text.labelLarge?.copyWith(color: p.accent)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_outward, size: 16, color: p.accent),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HonorCard extends StatelessWidget {
  const _HonorCard({required this.honor});
  final Honor honor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (honor.image != null)
          SmartImage(
            asset: honor.image,
            dropPath: 'frontend/${honor.image}',
            label: honor.title,
            natural: true,
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.military_tech, color: p.gold),
              if (honor.date.isNotEmpty) ...[const SizedBox(width: 8), Pill(honor.date, color: p.gold, mono: true)],
            ]),
            const SizedBox(height: 12),
            Text(honor.title, style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text('Conferred by ${honor.conferredBy}', style: context.text.labelLarge?.copyWith(color: p.accent)),
            const SizedBox(height: 10),
            Text(honor.citation, style: context.text.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}
