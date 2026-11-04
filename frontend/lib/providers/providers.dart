import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_item.dart';
import '../models/metrics.dart';
import '../models/profile.dart';
import '../models/publication.dart';
import '../services/api_client.dart';
import '../services/portfolio_repository.dart';
import '../services/seed_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final seedStoreProvider = Provider<SeedStore>((ref) => SeedStore());
final repositoryProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(ref.watch(apiClientProvider), ref.watch(seedStoreProvider)),
);

final profileProvider = FutureProvider<Profile>((ref) => ref.watch(repositoryProvider).profile());
final metricsProvider = FutureProvider<Metrics>((ref) => ref.watch(repositoryProvider).metrics());
final galleryProvider = FutureProvider<List<GalleryItem>>((ref) => ref.watch(repositoryProvider).gallery());
final allPublicationsProvider =
    FutureProvider<List<Publication>>((ref) => ref.watch(repositoryProvider).allPublications());

class PublicationQueryNotifier extends Notifier<PublicationQuery> {
  @override
  PublicationQuery build() => const PublicationQuery();

  void setSearch(String v) => state = state.copyWith(search: v);
  void setCategory(String v) => state = state.copyWith(category: v);
  void setSort(PubSort v) => state = state.copyWith(sort: v);
}

final publicationQueryProvider =
    NotifierProvider<PublicationQueryNotifier, PublicationQuery>(PublicationQueryNotifier.new);

final publicationsProvider = FutureProvider<List<Publication>>(
  (ref) => ref.watch(repositoryProvider).publications(ref.watch(publicationQueryProvider)),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  // Light by default regardless of the OS setting; the navbar toggle switches.
  ThemeMode build() => ThemeMode.light;

  void toggle(Brightness current) => state = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
