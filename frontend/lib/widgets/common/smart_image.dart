import 'package:flutter/material.dart';

import '../../models/gallery_item.dart';
import '../../services/config.dart';
import '../../theme/app_theme.dart';

/// Renders a bundled asset or backend image, falling back to a branded
/// placeholder that tells the editor exactly where to drop the file.
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    this.asset,
    this.url,
    required this.dropPath,
    this.label,
    this.fit = BoxFit.cover,
    this.compact = false,
    // People photos: bias crops upward so heads aren't cut off.
    this.alignment = const Alignment(0, -0.4),
    this.decodeWidth,
    this.natural = false,
  });

  final Alignment alignment;

  /// Fill the available width at the photo's own aspect ratio, so the whole
  /// photo shows with no cropping. Needs unbounded height.
  final bool natural;

  /// Decode at this pixel width instead of full resolution. Thumbnails of
  /// 2048px photos otherwise cost ~16 MB each and exhaust the image cache.
  final int? decodeWidth;

  /// Gallery tiles (compact) decode at thumbnail size; the lightbox doesn't.
  factory SmartImage.gallery(
    GalleryItem item, {
    BoxFit fit = BoxFit.cover,
    bool compact = false,
    bool natural = false,
  }) => SmartImage(
    asset: item.asset,
    url: item.url,
    dropPath: item.dropPath,
    label: item.caption,
    fit: fit,
    compact: compact,
    natural: natural,
    decodeWidth: compact ? 900 : null,
  );

  final String? asset, url, label;
  final String dropPath;
  final BoxFit fit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // In natural mode the image has no height of its own until it decodes,
    // so stand-ins get a 4:3 box.
    Widget box(Widget w) =>
        natural ? AspectRatio(aspectRatio: 4 / 3, child: w) : w;
    Widget fallback(BuildContext c, Object e, StackTrace? s) => box(
      PhotoPlaceholder(dropPath: dropPath, label: label, compact: compact),
    );
    Widget pending() => box(ColoredBox(color: context.palette.surfaceAlt));
    final width = natural ? double.infinity : null;
    Widget frame(BuildContext c, Widget child, int? f, bool sync) =>
        natural && f == null && !sync ? pending() : child;

    if (url != null) {
      return Image.network(
        AppConfig.backendUri(url!).toString(),
        width: width,
        fit: fit,
        alignment: alignment,
        cacheWidth: decodeWidth,
        errorBuilder: fallback,
        frameBuilder: frame,
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : box(
                ColoredBox(
                  color: context.palette.surfaceAlt,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
      );
    }
    if (asset != null) {
      return Image.asset(
        asset!,
        width: width,
        fit: fit,
        alignment: alignment,
        cacheWidth: decodeWidth,
        errorBuilder: fallback,
        frameBuilder: frame,
      );
    }
    return box(
      PhotoPlaceholder(dropPath: dropPath, label: label, compact: compact),
    );
  }
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.dropPath,
    this.label,
    this.compact = false,
  });

  final String dropPath;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.surfaceAlt, p.surface],
        ),
      ),
      padding: EdgeInsets.all(compact ? 12 : 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: compact ? 26 : 36,
              color: p.gold,
            ),
            if (label != null && !compact) ...[
              const SizedBox(height: 10),
              Text(
                label!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(color: p.ink),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Photo not added yet. Drop it at:',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 4),
            SelectableText(
              dropPath,
              textAlign: TextAlign.center,
              style: context.mono(size: compact ? 10 : 11, color: p.accent),
            ),
          ],
        ),
      ),
    );
  }
}
