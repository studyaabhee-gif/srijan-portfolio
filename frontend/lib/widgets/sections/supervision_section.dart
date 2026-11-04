import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../screens/sections.dart';
import '../../theme/app_theme.dart';
import '../common/layout.dart';

class SupervisionSection extends ConsumerWidget {
  const SupervisionSection({super.key, required this.onNavigate});

  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    return SectionShell(
      child: AsyncBlock(
        value: ref.watch(profileProvider),
        builder: (p) {
          final left = _ScholarsPanel(profile: p, onNavigate: onNavigate);
          final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _TeachingCard(profile: p),
            const SizedBox(height: 20),
            _InstitutionCard(profile: p),
          ]);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
              eyebrow: 'Supervision & Teaching',
              title: 'For prospective PhD and MSc scholars',
              subtitle: 'Research supervision and graduate teaching at the Central Department of Statistics, '
                  'Institute of Science and Technology, Tribhuvan University.',
            ),
            if (size.isCompact) ...[left, const SizedBox(height: 24), right]
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 7, child: left),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: right),
              ]),
          ]);
        },
      ),
    );
  }
}

class _ScholarsPanel extends StatelessWidget {
  const _ScholarsPanel({required this.profile, required this.onNavigate});
  final Profile profile;
  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = profile.supervision;
    final mobile = screenSize(context).isMobile;
    return Container(
      padding: EdgeInsets.all(mobile ? 22 : 32),
      decoration: BoxDecoration(
        color: Brand.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Pill('Now welcoming enquiries', color: Brand.goldLight, icon: Icons.mark_email_unread_outlined),
        const SizedBox(height: 18),
        Text(s.intro, style: context.text.bodyLarge?.copyWith(color: const Color(0xFFE2E6EE))),
        const SizedBox(height: 24),
        Text('Supervision areas', style: context.text.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 12),
        for (final a in s.areas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.check_circle_outline, size: 18, color: Brand.goldLight),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(a, style: context.text.bodyMedium?.copyWith(color: const Color(0xFFE2E6EE)))),
            ]),
          ),
        const SizedBox(height: 18),
        Text('How to approach', style: context.text.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 12),
        for (final (i, step) in s.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Brand.goldLight)),
                child: Text('${i + 1}', style: context.mono(size: 11, color: Brand.goldLight, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(step, style: context.text.bodyMedium?.copyWith(color: const Color(0xFFE2E6EE)))),
            ]),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.navy),
          onPressed: () => onNavigate(Section.contact),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Send a supervision enquiry'),
        ),
      ]),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  const _TeachingCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.functions, color: p.accent),
            const SizedBox(width: 10),
            Text('Courses taught', style: context.text.titleLarge),
          ]),
          const SizedBox(height: 6),
          Text('MSc & PhD in Statistics, Tribhuvan University', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          for (final t in profile.teaching)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: p.surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Expanded(child: Text(t.subject, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                Text(t.levels.join(' · '), style: context.mono(size: 11, color: p.muted)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/images/logos/tu_logo.jpg',
              errorBuilder: (c, e, s) => Icon(Icons.account_balance, size: 40, color: p.gold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.department, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${profile.faculty}, ${profile.institution}', style: context.text.bodyMedium),
              const SizedBox(height: 6),
              Text(profile.location, style: context.text.labelMedium?.copyWith(color: p.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
