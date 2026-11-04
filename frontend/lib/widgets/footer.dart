import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/sections.dart';
import '../services/portfolio_repository.dart';
import '../theme/app_theme.dart';
import 'common/actions.dart';
import 'common/layout.dart';
import 'nav_bar.dart';

class SiteFooter extends ConsumerWidget {
  const SiteFooter({super.key, required this.onNavigate});

  final ValueChanged<Section> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = screenSize(context);
    final repo = ref.watch(repositoryProvider);
    final profile = ref.watch(profileProvider).value;
    const ink = Color(0xFFF1EDE6);
    const muted = Color(0xFF9CA6BA);

    final linkStyle = context.text.bodyMedium?.copyWith(color: muted);

    return Container(
      width: double.infinity,
      color: Brand.navy,
      padding: EdgeInsets.fromLTRB(size.gutter, 56, size.gutter, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.maxContentWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              spacing: 48,
              runSpacing: 32,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Crest(onDark: true),
                    const SizedBox(height: 16),
                    Text(
                      'Professor of Statistics, Central Department of Statistics, Institute of Science and Technology, Tribhuvan University, Kirtipur, Kathmandu, Nepal.',
                      style: context.text.bodyMedium?.copyWith(color: muted),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Navigate', style: context.text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final s in Section.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(onTap: () => onNavigate(s), child: Text(s.label, style: linkStyle)),
                    ),
                ]),
                if (profile != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Profiles', style: context.text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (final l in profile.links)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(onTap: () => openLink(context, Uri.parse(l.url)), child: Text(l.label, style: linkStyle)),
                      ),
                  ]),
              ],
            ),
            const SizedBox(height: 40),
            Divider(color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('© ${DateTime.now().year} Prof. Dr. Srijan Lal Shrestha', style: context.text.bodySmall?.copyWith(color: muted)),
                ValueListenableBuilder(
                  valueListenable: repo.source,
                  builder: (context, src, _) {
                    final (label, color) = switch (src) {
                      DataSource.live => ('Live data · Go API', const Color(0xFF4ADE80)),
                      DataSource.offline => ('Offline mode · bundled seed data', Brand.goldLight),
                      DataSource.unknown => ('Connecting…', muted),
                    };
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 8, color: color),
                      const SizedBox(width: 8),
                      Text(label, style: context.mono(size: 11, color: muted)),
                    ]);
                  },
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
