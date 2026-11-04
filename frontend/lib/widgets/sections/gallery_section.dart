import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gallery_item.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../common/layout.dart';
import '../common/smart_image.dart';

class GallerySection extends ConsumerStatefulWidget {
  const GallerySection({super.key});

  @override
  ConsumerState<GallerySection> createState() => _GallerySectionState();
}

class _GallerySectionState extends ConsumerState<GallerySection> {
  GalleryCategory _filter = GalleryCategory.all;

  @override
  Widget build(BuildContext context) {
    final size = screenSize(context);
    return SectionShell(
      alt: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Photo Gallery',
            title: 'Moments from an academic life',
            subtitle:
                'Conferences and keynotes, life at the Central Department of Statistics, honours, '
                'and moments beyond the classroom. '
                'Select any photo to open it full screen, then pinch or scroll to zoom.',
          ),
          AsyncBlock(
            value: ref.watch(galleryProvider),
            builder: (all) {
              final items = _filter == GalleryCategory.all
                  ? all
                  : all.where((i) => i.category == _filter).toList();
              final cols = switch (size) {
                ScreenSize.mobile => 1,
                ScreenSize.tablet => 2,
                ScreenSize.laptop => 3,
                ScreenSize.wide => 4,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Hide empty categories so the public site never shows "(0)".
                      for (final c in GalleryCategory.values)
                        if (c == GalleryCategory.all ||
                            all.any((i) => i.category == c))
                          ChoiceChip(
                            label: Text(
                              '${c.label} (${c == GalleryCategory.all ? all.length : all.where((i) => i.category == c).length})',
                            ),
                            selected: _filter == c,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = c),
                          ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No photos in this category yet.',
                        style: context.text.bodyMedium,
                      ),
                    )
                  else
                    _Masonry(
                      columns: cols,
                      items: items,
                      onOpen: (i) => openLightbox(context, items, i),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Masonry: every tile keeps its photo's own aspect ratio (no cropping) and
/// goes into whichever column is currently shortest, so the columns end at
/// roughly the same height.
class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.columns,
    required this.items,
    required this.onOpen,
  });

  final int columns;
  final List<GalleryItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return MasonryLayout(
      columns: columns,
      gap: 16,
      children: [
        for (var i = 0; i < items.length; i++)
          _Tile(
            key: ValueKey(items[i].id),
            item: items[i],
            onTap: () => onOpen(i),
          ),
      ],
    );
  }
}

/// Lays children out at equal column width, each into the shortest column.
/// Placement uses each tile's real laid-out height, and it re-runs when a
/// photo finishes loading and changes size.
class MasonryLayout extends MultiChildRenderObjectWidget {
  const MasonryLayout({
    super.key,
    required this.columns,
    required this.gap,
    required super.children,
  });

  final int columns;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMasonry(columns, gap);

  @override
  void updateRenderObject(BuildContext context, RenderMasonry renderObject) {
    renderObject
      ..columns = columns
      ..gap = gap;
  }
}

class _MasonryParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMasonry extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MasonryParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MasonryParentData> {
  RenderMasonry(this._columns, this._gap);

  int _columns;
  set columns(int v) {
    if (v == _columns) return;
    _columns = v;
    markNeedsLayout();
  }

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryParentData) {
      child.parentData = _MasonryParentData();
    }
  }

  double _colWidth(double width) =>
      ((width - _gap * (_columns - 1)) / _columns).clamp(0, double.infinity);

  /// Places children and returns the total height.
  double _place(
    double width,
    Size Function(RenderBox, BoxConstraints) measure, {
    bool commit = false,
  }) {
    final colW = _colWidth(width);
    final heights = List.filled(_columns, 0.0);
    for (var c = firstChild; c != null; c = childAfter(c)) {
      var col = 0;
      for (var k = 1; k < _columns; k++) {
        if (heights[k] < heights[col] - 0.5) col = k;
      }
      final s = measure(c, BoxConstraints.tightFor(width: colW));
      if (commit) {
        (c.parentData! as _MasonryParentData).offset = Offset(
          col * (colW + _gap),
          heights[col],
        );
      }
      heights[col] += s.height + _gap;
    }
    final tallest = heights.reduce((a, b) => a > b ? a : b);
    return tallest > 0 ? tallest - _gap : 0;
  }

  @override
  void performLayout() {
    final h = _place(constraints.maxWidth, (c, bc) {
      c.layout(bc, parentUsesSize: true);
      return c.size;
    }, commit: true);
    size = constraints.constrain(Size(constraints.maxWidth, h));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.maxWidth,
      _place(constraints.maxWidth, (c, bc) => c.getDryLayout(bc)),
    ),
  );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _Tile extends StatefulWidget {
  const _Tile({super.key, required this.item, required this.onTap});
  final GalleryItem item;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final it = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? p.gold : p.border),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Hero(
                tag: 'gallery-${it.id}',
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 400),
                  scale: _hover ? 1.04 : 1,
                  child: SmartImage.gallery(it, compact: true, natural: true),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          it.category.label.toUpperCase(),
                          style: context
                              .mono(
                                size: 9.5,
                                weight: FontWeight.w600,
                                color: Brand.goldLight,
                              )
                              .copyWith(letterSpacing: 1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openLightbox(
  BuildContext context,
  List<GalleryItem> items,
  int initial,
) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close photo',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _Lightbox(items: items, initial: initial),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.items, required this.initial});
  final List<GalleryItem> items;
  final int initial;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final _focus = FocusNode();

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    if (next != _index) {
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final mobile = screenSize(context).isMobile;
    const white = Colors.white;
    const muted = Color(0xFFB8C0D0);

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) _go(1);
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) _go(-1);
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Text(
                      '${_index + 1} / ${widget.items.length}',
                      style: context.mono(size: 13, color: muted),
                    ),
                    const Spacer(),
                    const Text(
                      'Scroll or pinch to zoom',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close (Esc)',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PageView.builder(
                      controller: _pages,
                      itemCount: widget.items.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        final it = widget.items[i];
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: mobile ? 8 : 80,
                                vertical: 12,
                              ),
                              child: Hero(
                                tag: 'gallery-${it.id}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SmartImage.gallery(
                                    it,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (!mobile && _index > 0)
                      Positioned(
                        left: 16,
                        child: _NavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => _go(-1),
                        ),
                      ),
                    if (!mobile && _index < widget.items.length - 1)
                      Positioned(
                        right: 16,
                        child: _NavArrow(
                          icon: Icons.chevron_right,
                          onTap: () => _go(1),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    Text(
                      item.caption,
                      textAlign: TextAlign.center,
                      style: context.text.titleLarge?.copyWith(color: white),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Pill(item.category.label, color: Brand.goldLight),
                        if (item.date != null)
                          Pill(
                            item.date!,
                            color: muted,
                            icon: Icons.event,
                            mono: true,
                          ),
                        if (item.location != null)
                          Pill(
                            item.location!,
                            color: muted,
                            icon: Icons.place_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    icon: Icon(icon, size: 30),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(12),
    ),
  );
}
