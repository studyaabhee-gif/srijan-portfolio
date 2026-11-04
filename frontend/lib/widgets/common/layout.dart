import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

enum ScreenSize { mobile, tablet, laptop, wide }

ScreenSize screenSizeOf(double width) {
  if (width < 640) return ScreenSize.mobile;
  if (width < 1024) return ScreenSize.tablet;
  if (width < 1440) return ScreenSize.laptop;
  return ScreenSize.wide;
}

extension ScreenSizeX on ScreenSize {
  bool get isMobile => this == ScreenSize.mobile;
  bool get isCompact => this == ScreenSize.mobile || this == ScreenSize.tablet;
  double get maxContentWidth => this == ScreenSize.wide ? 1360 : 1200;
  double get gutter => switch (this) {
    ScreenSize.mobile => 16,
    ScreenSize.tablet => 28,
    _ => 40,
  };
}

ScreenSize screenSize(BuildContext context) =>
    screenSizeOf(MediaQuery.sizeOf(context).width);

/// Centred, width-constrained section band with consistent vertical rhythm.
class SectionShell extends StatelessWidget {
  const SectionShell({
    super.key,
    required this.child,
    this.alt = false,
    this.top = 88,
    this.bottom = 88,
  });

  final Widget child;
  final bool alt;
  final double top, bottom;

  @override
  Widget build(BuildContext context) {
    final size = screenSize(context);
    final scale = size.isMobile ? 0.6 : 1.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: alt ? context.palette.surfaceAlt.withValues(alpha: 0.55) : null,
        border: alt
            ? Border.symmetric(
                horizontal: BorderSide(color: context.palette.border),
              )
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        size.gutter,
        top * scale,
        size.gutter,
        bottom * scale,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow, title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mobile = screenSize(context).isMobile;
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 2, color: p.accent),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  eyebrow.toUpperCase(),
                  style: context
                      .mono(size: 12, weight: FontWeight.w600, color: p.accent)
                      .copyWith(letterSpacing: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: (mobile
                ? context.text.headlineMedium
                : context.text.displaySmall),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                subtitle!,
                style: context.text.bodyLarge?.copyWith(color: p.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays children out in [columns] equal-width columns, wrapping into rows.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = 20,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns).clamp(0, children.length),
      );
      rows.add(
        _EqualHeightRow(
          columns: columns,
          gap: gap,
          children: [
            for (var j = 0; j < columns; j++)
              j < slice.length ? slice[j] : const SizedBox.shrink(),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }
}

/// Equal-width cells stretched to the tallest cell's height.
///
/// Unlike `IntrinsicHeight`, this lays each child out for real to find the
/// tallest one, so wrapping text and late-loading web fonts can't make a
/// cell overflow.
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({
    required this.columns,
    required this.gap,
    required super.children,
  });

  final int columns;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(columns, gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..columns = columns
      ..gap = gap;
  }
}

class _CellParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CellParentData> {
  _RenderEqualHeightRow(this._columns, this._gap);

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
    if (child.parentData is! _CellParentData) {
      child.parentData = _CellParentData();
    }
  }

  double _cellWidth(double maxWidth) =>
      ((maxWidth - _gap * (_columns - 1)) / _columns).clamp(0, double.infinity);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final cell = _cellWidth(width);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: cell), parentUsesSize: true);
      if (child.size.height > tallest) tallest = child.size.height;
      child = childAfter(child);
    }
    // Stretch to the tallest cell with a minHeight, never a tight height: a
    // tightly sized child becomes a relayout boundary, so a late font load
    // (e.g. the Devanagari fallback) would re-lay the card out inside a stale
    // height and overflow instead of growing the row.
    var x = 0.0;
    var rowHeight = tallest;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints(minWidth: cell, maxWidth: cell, minHeight: tallest),
        parentUsesSize: true,
      );
      if (child.size.height > rowHeight) rowHeight = child.size.height;
      (child.parentData! as _CellParentData).offset = Offset(x, 0);
      x += cell + _gap;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, rowHeight));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _maxChildHeight(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _maxChildHeight(width, (c, w) => c.getMaxIntrinsicHeight(w));

  double _maxChildHeight(
    double width,
    double Function(RenderBox, double) measure,
  ) {
    final cell = _cellWidth(width);
    var h = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final v = measure(c, cell);
      if (v > h) h = v;
    }
    return h;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

/// Small rounded label used for journals, categories and badges.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon, this.mono = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.muted;
    final style = mono
        ? context.mono(size: 11.5, weight: FontWeight.w600, color: c)
        : context.text.labelMedium?.copyWith(
            color: c,
            fontWeight: FontWeight.w600,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Loading / error wrapper for section-level async data.
class AsyncBlock<T> extends StatelessWidget {
  const AsyncBlock({
    super.key,
    required this.value,
    required this.builder,
    this.minHeight = 240,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final data = value.value;
    if (data != null) return builder(data);
    if (value.hasError) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: Text(
            'Could not load this section.',
            style: context.text.bodyMedium,
          ),
        ),
      );
    }
    return SizedBox(
      height: minHeight,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
