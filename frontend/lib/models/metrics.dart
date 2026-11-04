import 'json_utils.dart';
import 'publication.dart';

class YearPoint {
  const YearPoint(this.year, this.publications, this.citations, this.cumulativeCitations);
  final int year, publications, citations, cumulativeCitations;
  factory YearPoint.fromJson(Json j) => YearPoint(
        integer(j['year']),
        integer(j['publications']),
        integer(j['citations']),
        integer(j['cumulativeCitations']),
      );
}

class CountItem {
  const CountItem(this.label, this.count);
  final String label;
  final int count;
  factory CountItem.fromJson(Json j) => CountItem(str(j['label']), integer(j['count']));
}

class Metrics {
  const Metrics({
    required this.yearsOfService,
    required this.coAuthors,
    required this.reportedCitations,
    required this.phdSupervised,
    required this.mscSupervised,
    required this.note,
    required this.totalPublications,
    required this.seededCitations,
    required this.hIndex,
    required this.i10Index,
    required this.byYear,
    required this.byCategory,
    required this.byDomain,
  });

  final int yearsOfService, coAuthors, reportedCitations;
  final int? phdSupervised, mscSupervised;
  final String note;
  final int totalPublications, seededCitations, hIndex, i10Index;
  final List<YearPoint> byYear;
  final List<CountItem> byCategory, byDomain;

  factory Metrics.fromJson(Json j) => Metrics(
        yearsOfService: integer(j['yearsOfService']),
        coAuthors: integer(j['coAuthors']),
        reportedCitations: integer(j['reportedCitations']),
        phdSupervised: optInt(j['phdSupervised']),
        mscSupervised: optInt(j['mscSupervised']),
        note: str(j['note']),
        totalPublications: integer(j['totalPublications']),
        seededCitations: integer(j['seededCitations']),
        hIndex: integer(j['hIndex']),
        i10Index: integer(j['i10Index']),
        byYear: objects(j['byYear'], YearPoint.fromJson),
        byCategory: objects(j['byCategory'], CountItem.fromJson),
        byDomain: objects(j['byDomain'], CountItem.fromJson),
      );

  /// Mirror of the Go backend's store.ComputeMetrics, for offline mode.
  factory Metrics.compute(List<Publication> pubs, Json base) {
    final cites = pubs.map((p) => p.citations).toList()..sort((a, b) => b.compareTo(a));
    var h = 0, i10 = 0;
    for (var i = 0; i < cites.length; i++) {
      if (cites[i] >= i + 1) h = i + 1;
      if (cites[i] >= 10) i10++;
    }

    final pubsByYear = <int, int>{}, citesByYear = <int, int>{};
    final cat = <String, int>{}, dom = <String, int>{};
    for (final p in pubs) {
      cat[p.category] = (cat[p.category] ?? 0) + 1;
      dom[p.domain] = (dom[p.domain] ?? 0) + 1;
      if (p.year != null) {
        pubsByYear[p.year!] = (pubsByYear[p.year!] ?? 0) + 1;
        citesByYear[p.year!] = (citesByYear[p.year!] ?? 0) + p.citations;
      }
    }
    var cum = 0;
    final byYear = <YearPoint>[];
    for (var y = 2004; y <= 2026; y++) {
      final c = citesByYear[y] ?? 0;
      cum += c;
      byYear.add(YearPoint(y, pubsByYear[y] ?? 0, c, cum));
    }

    List<CountItem> sorted(Map<String, int> m) => m.entries.map((e) => CountItem(e.key, e.value)).toList()
      ..sort((a, b) => a.count != b.count ? b.count.compareTo(a.count) : a.label.compareTo(b.label));

    return Metrics(
      yearsOfService: integer(base['yearsOfService']),
      coAuthors: integer(base['coAuthors']),
      reportedCitations: integer(base['reportedCitations']),
      phdSupervised: optInt(base['phdSupervised']),
      mscSupervised: optInt(base['mscSupervised']),
      note: str(base['note']),
      totalPublications: pubs.length,
      seededCitations: pubs.fold(0, (s, p) => s + p.citations),
      hIndex: h,
      i10Index: i10,
      byYear: byYear,
      byCategory: sorted(cat),
      byDomain: sorted(dom),
    );
  }
}
