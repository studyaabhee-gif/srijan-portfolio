import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../services/config.dart';
import '../widgets/common/actions.dart';
import '../widgets/footer.dart';
import '../widgets/nav_bar.dart';
import '../widgets/sections/contact_section.dart';
import '../widgets/sections/gallery_section.dart';
import '../widgets/sections/hero_section.dart';
import '../widgets/sections/impact_section.dart';
import '../widgets/sections/leadership_section.dart';
import '../widgets/sections/research_section.dart';
import '../widgets/sections/supervision_section.dart';
import 'sections.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.section});

  final Section section;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _keys = {for (final s in Section.values) s: GlobalKey(debugLabel: s.name)};
  late Section _active = widget.section;
  bool _scrolled = false;
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.section != Section.overview) {
      // Deep link: data, web fonts and images above the target arrive over
      // the first seconds and shift layout. Keep the target pinned on every
      // layout change until the visitor scrolls or navigates themselves.
      _pinned = widget.section;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(widget.section, animate: false));
    }
  }

  /// Section kept in view while the page is still settling after a deep link.
  Section? _pinned;
  bool _repinScheduled = false;

  void _releasePin() => _pinned = null;

  bool _onMetricsChanged(ScrollMetricsNotification n) {
    final target = _pinned;
    if (target != null && !_repinScheduled) {
      _repinScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _repinScheduled = false;
        if (mounted && _pinned == target) _scrollTo(target, animate: false);
      });
    }
    return false;
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    // Browser back/forward or a pasted URL.
    if (old.section != widget.section) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(widget.section));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 8;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    if (_programmatic) return;

    // Scroll-spy: the last section whose top has passed below the nav bar.
    var current = Section.overview;
    for (final s in Section.values) {
      final ctx = _keys[s]!.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= kNavHeight + 140) current = s;
    }
    if (current != _active) setState(() => _active = current);
  }

  Future<void> _scrollTo(Section s, {bool animate = true}) async {
    final ctx = _keys[s]!.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    final ro = ctx.findRenderObject();
    if (ro == null) return;
    final viewport = RenderAbstractViewport.of(ro);
    final target = s == Section.overview
        ? 0.0
        : (viewport.getOffsetToReveal(ro, 0).offset - kNavHeight + 8).clamp(0.0, _scroll.position.maxScrollExtent);

    setState(() => _active = s);
    _programmatic = true;
    if (animate) {
      await _scroll.animateTo(target, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
    _programmatic = false;
  }

  void _navigate(Section s) {
    _releasePin();
    if (s.path != GoRouterState.of(context).uri.path) context.go(s.path);
    _scrollTo(s);
  }

  void _downloadCv() {
    final repo = ref.read(repositoryProvider);
    final path = repo.isLive
        ? AppConfig.backendUri('/static/cv/${AppConfig.cvFileName}')
        // Flutter web serves bundled assets under /assets/<asset path>.
        : Uri.base.resolve('/assets/${AppConfig.cvAsset}');
    // Version tag so a newly deployed CV is never served from cache.
    final uri = path.replace(queryParameters: {'v': AppConfig.buildId});
    openLink(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    Widget anchor(Section s, Widget child) => KeyedSubtree(key: _keys[s], child: child);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: NavDrawer(active: _active, onNavigate: _navigate, onDownloadCv: _downloadCv),
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              // Any pointer/wheel input means the visitor has taken over.
              onPointerDown: (_) => _releasePin(),
              onPointerSignal: (_) => _releasePin(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Keyboard, wheel, drag and scrollbar scrolls all count.
                  if (n is UserScrollNotification) _releasePin();
                  return false;
                },
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onMetricsChanged,
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        children: [
                          anchor(Section.overview, HeroSection(onNavigate: _navigate)),
                          anchor(Section.leadership, const LeadershipSection()),
                          anchor(Section.research, const ResearchSection()),
                          anchor(Section.impact, const ImpactSection()),
                          anchor(Section.gallery, const GallerySection()),
                          anchor(Section.teaching, SupervisionSection(onNavigate: _navigate)),
                          anchor(Section.contact, const ContactSection()),
                          SiteFooter(onNavigate: _navigate),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopNavBar(
              active: _active,
              scrolled: _scrolled,
              onNavigate: _navigate,
              onDownloadCv: _downloadCv,
              onOpenMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
    );
  }
}
