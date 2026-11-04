import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/gallery_item.dart';
import '../models/json_utils.dart';
import '../models/metrics.dart';
import '../models/profile.dart';
import '../models/publication.dart';

/// Local fallback layer: the same portfolio_seed.json the backend embeds,
/// bundled as a Flutter asset so the site renders fully without a server.
class SeedStore {
  SeedStore({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/portfolio_seed.json';
  final AssetBundle _bundle;
  Future<Json>? _raw;

  Future<Json> _load() => _raw ??= _bundle.loadString(assetPath).then((s) => jsonDecode(s) as Json);

  Future<Profile> profile() async => Profile.fromJson((await _load())['profile'] as Json);

  Future<List<Publication>> publications() async => objects((await _load())['publications'], Publication.fromJson);

  Future<Metrics> metrics() async {
    final raw = await _load();
    return Metrics.compute(await publications(), Map<String, dynamic>.from(raw['metricsBase'] as Map));
  }

  Future<List<GalleryItem>> gallery() async => objects((await _load())['gallery'], GalleryItem.fromJson);
}
