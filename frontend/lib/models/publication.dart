import 'json_utils.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class Publication {
  const Publication({
    required this.id,
    required this.title,
    required this.authors,
    required this.journal,
    required this.category,
    required this.domain,
    required this.keywords,
    required this.summary,
    this.volume,
    this.issue,
    this.pages,
    this.articleNo,
    this.year,
    this.month,
    this.citations = 0,
    this.url,
    this.doi,
  });

  final String id, title, journal, category, domain, summary;
  final List<String> authors, keywords;
  final String? volume, issue, pages, articleNo, url, doi;
  final int? year, month;
  final int citations;

  factory Publication.fromJson(Json j) => Publication(
        id: str(j['id']),
        title: str(j['title']),
        authors: strings(j['authors']),
        journal: str(j['journal']),
        volume: optStr(j['volume']),
        issue: optStr(j['issue']),
        pages: optStr(j['pages']),
        articleNo: optStr(j['articleNo']),
        year: optInt(j['year']),
        month: optInt(j['month']),
        citations: integer(j['citations']),
        category: str(j['category']),
        domain: str(j['domain']),
        keywords: strings(j['keywords']),
        summary: str(j['summary']),
        url: optStr(j['url']),
        doi: optStr(j['doi']),
      );

  int get dateKey => (year ?? 0) * 100 + (month ?? 0);

  String get dateLabel {
    if (year == null) return 'n.d.';
    final m = month;
    return (m != null && m >= 1 && m <= 12) ? '${_months[m - 1]} $year' : '$year';
  }

  /// Co-authors other than Prof. Shrestha, for display.
  List<String> get coAuthors => authors.where((a) => a != 'S.L. Shrestha').toList();

  /// "Vol. 19(3), pp. 945–958" style source details.
  String get sourceDetails {
    final parts = <String>[];
    if (volume != null) parts.add(issue != null ? 'Vol. $volume($issue)' : 'Vol. $volume');
    if (articleNo != null) parts.add('Art. $articleNo');
    if (pages != null) parts.add('pp. $pages');
    return parts.join(', ');
  }

  /// Link target: explicit URL/DOI, else a Google Scholar title search.
  Uri get externalUri {
    if (doi != null) return Uri.parse('https://doi.org/$doi');
    if (url != null) return Uri.parse(url!);
    return scholarUri;
  }

  Uri get scholarUri => Uri.https('scholar.google.com', '/scholar', {'q': '"$title"'});

  bool matches(String needle) {
    final n = needle.toLowerCase();
    return [title, journal, category, summary, authors.join(' '), keywords.join(' ')]
        .any((h) => h.toLowerCase().contains(n));
  }

  String toBibtex() {
    String bibName(String a) {
      if (a == 'et al.') return 'others';
      final i = a.lastIndexOf(' ');
      return i < 0 ? a : '${a.substring(i + 1)}, ${a.substring(0, i)}';
    }

    final firstWord = title.split(RegExp(r'\W+')).firstWhere((w) => w.length > 3, orElse: () => 'paper').toLowerCase();
    final key = 'shrestha${year ?? 'nd'}$firstWord';
    final fields = <String, String?>{
      'title': '{$title}',
      'author': authors.map(bibName).join(' and '),
      'journal': journal,
      'year': year?.toString(),
      'volume': volume,
      'number': issue,
      'pages': pages?.replaceAll('–', '--'),
      'note': articleNo != null ? 'Article $articleNo' : null,
      'doi': doi,
      'url': url,
    }..removeWhere((_, v) => v == null);
    final body = fields.entries.map((e) => '  ${e.key} = {${e.value}}').join(',\n');
    return '@article{$key,\n$body\n}';
  }
}

enum PubSort {
  cited('citations', 'Most Cited'),
  newest('year', 'Newest First'),
  oldest('year_asc', 'Oldest First');

  const PubSort(this.apiValue, this.label);
  final String apiValue, label;
}

class PublicationQuery {
  const PublicationQuery({this.search = '', this.category = 'All', this.sort = PubSort.newest});
  final String search, category;
  final PubSort sort;

  PublicationQuery copyWith({String? search, String? category, PubSort? sort}) => PublicationQuery(
        search: search ?? this.search,
        category: category ?? this.category,
        sort: sort ?? this.sort,
      );

  /// Local implementation of the backend's filter/sort, used for the fallback.
  List<Publication> apply(List<Publication> all) {
    final s = search.trim();
    final out = all
        .where((p) => category == 'All' || p.category.toLowerCase() == category.toLowerCase())
        .where((p) => s.isEmpty || p.matches(s))
        .toList();
    switch (sort) {
      case PubSort.cited:
        mergeSort(out, (a, b) => b.citations.compareTo(a.citations));
      case PubSort.newest:
        mergeSort(out, (a, b) => b.dateKey.compareTo(a.dateKey));
      case PubSort.oldest:
        mergeSort(out, (a, b) => a.dateKey.compareTo(b.dateKey));
    }
    return out;
  }
}

/// Stable sort (List.sort isn't guaranteed stable), matching Go's SliceStable.
void mergeSort<T>(List<T> list, int Function(T, T) compare) {
  if (list.length < 2) return;
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}
