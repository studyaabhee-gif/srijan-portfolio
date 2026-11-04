import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/sections.dart';
import '../theme/app_theme.dart';
import 'common/layout.dart';

const double kNavHeight = 72;

class Crest extends StatelessWidget {
  const Crest({super.key, this.compact = false, this.onDark = false});

  final bool compact, onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = onDark ? const Color(0xFFF1EDE6) : p.ink;
    final gold = onDark ? Brand.goldLight : p.gold;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Tribhuvan University crest. The JPG has a white background, so it
      // sits in a white disc that reads well in both themes.
      Tooltip(
        message: 'Tribhuvan University',
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Brand.gold, width: 1.5),
          ),
          child: Image.asset(
            'assets/images/logos/tu_logo.jpg',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Tribhuvan University logo',
            errorBuilder: (_, _, _) => Center(
              child: Text('SLS',
                  style: context.text.labelLarge?.copyWith(
                    fontFamily: context.text.titleLarge?.fontFamily,
                    color: Brand.navy,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(compact ? 'Prof. Dr. S. L. Shrestha' : 'Prof. Dr. Srijan Lal Shrestha',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(
                  fontFamily: context.text.titleLarge?.fontFamily,
                  fontWeight: FontWeight.w700,
                  color: ink,
                )),
            Text('PhD (Statistics)', maxLines: 1, softWrap: false, style: context.mono(size: 11, color: gold)),
          ],
        ),
      ),
    ]);
  }
}

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => RotationTransition(turns: a, child: FadeTransition(opacity: a, child: c)),
        child: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, key: ValueKey(dark)),
      ),
    );
  }
}

class TopNavBar extends StatelessWidget {
  const TopNavBar({
    super.key,
    required this.active,
    required this.onNavigate,
    required this.onDownloadCv,
    required this.onOpenMenu,
    required this.scrolled,
  });

  final Section active;
  final ValueChanged<Section> onNavigate;
  final VoidCallback onDownloadCv, onOpenMenu;
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final size = screenSizeOf(width);
    final showLinks = width >= 1180;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: kNavHeight,
          decoration: BoxDecoration(
            color: scrolled ? p.glass : p.background.withValues(alpha: 0.4),
            border: Border(bottom: BorderSide(color: scrolled ? p.border : Colors.transparent)),
          ),
          padding: EdgeInsets.symmetric(horizontal: size.gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size == ScreenSize.wide ? 1440 : 1280),
              child: Row(children: [
                // Crest takes all free space (left-aligned) so it never has
                // to share it with a Spacer and get truncated.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onNavigate(Section.overview),
                      child: Crest(compact: size.isMobile),
                    ),
                  ),
                ),
                if (showLinks) ...[
                  for (final s in Section.values) _NavLink(section: s, active: s == active, onTap: () => onNavigate(s)),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onDownloadCv,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download CV'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  ),
                  const SizedBox(width: 4),
                  const ThemeToggle(),
                ] else ...[
                  if (!size.isMobile)
                    TextButton.icon(
                      onPressed: onDownloadCv,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('CV'),
                    ),
                  const ThemeToggle(),
                  IconButton(tooltip: 'Menu', onPressed: onOpenMenu, icon: const Icon(Icons.menu_rounded)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({required this.section, required this.active, required this.onTap});
  final Section section;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = widget.active || _hover;
    final label = switch (widget.section) {
      Section.research => 'Research',
      Section.impact => 'Impact',
      Section.gallery => 'Gallery',
      Section.teaching => 'Teaching',
      Section.leadership => 'Leadership',
      _ => widget.section.label,
    };
    return Tooltip(
      message: widget.section.label,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: context.text.labelLarge?.copyWith(
                    color: on ? p.ink : p.muted,
                    fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: widget.active ? 18 : (_hover ? 10 : 0),
                color: p.accent,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key, required this.active, required this.onNavigate, required this.onDownloadCv});

  final Section active;
  final ValueChanged<Section> onNavigate;
  final VoidCallback onDownloadCv;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Drawer(
      backgroundColor: p.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Crest()),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 24),
            for (final s in Section.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                selected: s == active,
                selectedColor: p.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: Text(s.label, style: context.text.titleMedium?.copyWith(
                  color: s == active ? p.accent : p.ink,
                  fontWeight: s == active ? FontWeight.w700 : FontWeight.w500,
                )),
                trailing: s == active ? Icon(Icons.circle, size: 8, color: p.accent) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onNavigate(s);
                },
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDownloadCv();
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download CV'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
