import 'json_utils.dart';

enum GalleryCategory {
  all('all', 'All'),
  conferences('conferences', 'Conferences & Keynotes'),
  lectures('lectures', 'Lectures & CDS Department'),
  research('research', 'Research & Fieldwork'),
  milestones('milestones', 'Awards & Milestones'),
  personal('personal', 'Beyond the Classroom');

  const GalleryCategory(this.id, this.label);
  final String id, label;

  static GalleryCategory parse(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => GalleryCategory.all);
}

class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.category,
    required this.caption,
    this.date,
    this.location,
    this.asset,
    this.url,
    this.source = 'seed',
  });

  final String id, caption, source;
  final GalleryCategory category;
  final String? date, location;

  /// Flutter bundle path, e.g. assets/images/gallery/research/x.jpg
  final String? asset;

  /// Backend-relative URL, e.g. /static/gallery/research/x.jpg
  final String? url;

  bool get isNetwork => url != null;

  /// Where a missing photo should be dropped, shown on placeholder cards.
  String get dropPath {
    if (asset != null) return 'frontend/$asset';
    final u = url ?? '';
    return u.startsWith('/static/gallery/') ? 'backend/storage/gallery/${u.substring(16)}' : u;
  }

  factory GalleryItem.fromJson(Json j) => GalleryItem(
        id: str(j['id']),
        category: GalleryCategory.parse(str(j['category'])),
        caption: str(j['caption']),
        date: optStr(j['date']),
        location: optStr(j['location']),
        asset: optStr(j['asset']),
        url: optStr(j['url']),
        source: str(j['source'], 'seed'),
      );
}
