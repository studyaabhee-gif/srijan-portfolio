import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:srijan_portfolio/models/gallery_item.dart';
import 'package:srijan_portfolio/models/json_utils.dart';
import 'package:srijan_portfolio/models/metrics.dart';
import 'package:srijan_portfolio/models/profile.dart';
import 'package:srijan_portfolio/models/publication.dart';

void main() {
  final raw = jsonDecode(File('assets/data/portfolio_seed.json').readAsStringSync()) as Json;
  final pubs = objects(raw['publications'], Publication.fromJson);

  test('frontend seed is identical to backend seed', () {
    final backend = File('../backend/data/portfolio_seed.json').readAsStringSync();
    expect(File('assets/data/portfolio_seed.json').readAsStringSync(), backend,
        reason: 'run `make sync-seed` after editing backend/data/portfolio_seed.json');
  });

  test('profile parses with verified identifiers', () {
    final p = Profile.fromJson(raw['profile'] as Json);
    expect(p.emails, contains('srijan.shrestha@cds.tu.edu.np'));
    expect(p.link('orcid')?.handle, '0000-0002-9390-8215');
    expect(p.honors, hasLength(3));
  });

  test('offline metrics match the Go backend', () {
    final m = Metrics.compute(pubs, Map<String, dynamic>.from(raw['metricsBase'] as Map));
    expect(m.totalPublications, 22);
    expect(m.hIndex, 7);
    expect(m.i10Index, 7);
    expect(m.byYear.first.year, 2004);
    expect(m.byYear.last.year, 2026);
  });

  test('local filter/sort mirrors API semantics', () {
    expect(const PublicationQuery(sort: PubSort.cited).apply(pubs).first.id, 'p20');
    expect(const PublicationQuery(search: 'banjade', category: 'HDI & Socio-Economic Modeling').apply(pubs), hasLength(3));
    expect(const PublicationQuery(sort: PubSort.newest).apply(pubs).first.id, 'p01');
  });

  test('bibtex is well formed', () {
    final bib = pubs.firstWhere((p) => p.id == 'p04').toBibtex();
    expect(bib, startsWith('@article{shrestha2024'));
    expect(bib, contains('author = {Banjade, I.P. and Shrestha, S.L.}'));
    expect(bib, contains('pages = {945--958}'));
  });

  test('gallery placeholders point at the right drop path', () {
    final items = objects(raw['gallery'], GalleryItem.fromJson);
    expect(items.firstWhere((i) => i.id == 'g-phd-festival-2023').dropPath,
        'frontend/assets/images/gallery/conferences/phd_festival_2023_plenary.jpg');
    // Every bundled gallery asset must actually exist on disk.
    for (final i in items.where((i) => i.asset != null)) {
      expect(File(i.asset!).existsSync(), isTrue, reason: '${i.asset} is missing');
    }
    const uploaded = GalleryItem(id: 'u', category: GalleryCategory.research, caption: 'x', url: '/static/gallery/research/a.jpg');
    expect(uploaded.dropPath, 'backend/storage/gallery/research/a.jpg');
  });
}
