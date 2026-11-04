import 'package:flutter/foundation.dart';

import '../models/gallery_item.dart';
import '../models/json_utils.dart';
import '../models/metrics.dart';
import '../models/profile.dart';
import '../models/publication.dart';
import 'api_client.dart';
import 'config.dart';
import 'seed_store.dart';

enum DataSource { unknown, live, offline }

/// Tries the Go API first and transparently falls back to the bundled seed.
/// After a connection failure it stays offline for a short cool-down so the
/// UI doesn't wait on a timeout for every request.
class PortfolioRepository {
  PortfolioRepository(this._api, this._seed);

  final ApiClient _api;
  final SeedStore _seed;
  final source = ValueNotifier(AppConfig.apiEnabled ? DataSource.unknown : DataSource.offline);
  DateTime? _offlineUntil;

  bool get _skipRemote =>
      !AppConfig.apiEnabled || (_offlineUntil != null && DateTime.now().isBefore(_offlineUntil!));

  Future<T> _resolve<T>(Future<T> Function() remote, Future<T> Function() local) async {
    if (!_skipRemote) {
      try {
        final v = await remote();
        _offlineUntil = null;
        source.value = DataSource.live;
        return v;
      } catch (e) {
        debugPrint('API unavailable, using seed: $e');
        _offlineUntil = DateTime.now().add(const Duration(seconds: 60));
      }
    }
    source.value = DataSource.offline;
    return local();
  }

  Future<Profile> profile() => _resolve(
        () async => Profile.fromJson(await _api.getJson('/profile')),
        _seed.profile,
      );

  Future<Metrics> metrics() => _resolve(
        () async => Metrics.fromJson(await _api.getJson('/metrics')),
        _seed.metrics,
      );

  /// All publications, unfiltered (used for category chips and counts).
  Future<List<Publication>> allPublications() => _seed.publications();

  Future<List<Publication>> publications(PublicationQuery q) => _resolve(
        () async {
          final res = await _api.getJson('/publications', query: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            if (q.category != 'All') 'category': q.category,
            'sort': q.sort.apiValue,
          });
          return objects(res['items'], Publication.fromJson);
        },
        () async => q.apply(await _seed.publications()),
      );

  /// Backend gallery (seed + uploads + discovered files), else seed only.
  Future<List<GalleryItem>> gallery() => _resolve(
        () async => objects((await _api.getJson('/gallery'))['items'], GalleryItem.fromJson),
        _seed.gallery,
      );

  /// Contact never falls back: the caller offers a mailto link instead.
  Future<String> sendContact(Json body) async {
    if (!AppConfig.apiEnabled) throw ApiException('Contact API is not configured for this deployment');
    final res = await _api.postJson('/contact', body);
    return str(res['id']);
  }

  bool get isLive => source.value == DataSource.live;
}
