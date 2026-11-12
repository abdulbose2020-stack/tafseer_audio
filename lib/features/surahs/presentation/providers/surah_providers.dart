import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/json_surah_repository.dart';
import '../../data/surah_asset_data_source.dart';
import '../../data/surah_data_source.dart';
import '../../domain/surah.dart';
import '../../domain/surah_filter.dart';
import '../../domain/surah_repository.dart';
import '../../domain/surah_search.dart';

/// Loads Surah metadata from the bundled JSON asset.
final surahDataSourceProvider = Provider<SurahDataSource>((ref) {
  return const SurahAssetDataSource();
});

/// Provides the Surah repository to the rest of the application.
final surahRepositoryProvider = Provider<SurahRepository>((ref) {
  return JsonSurahRepository(ref.watch(surahDataSourceProvider));
});

/// The complete, immutable Surah catalogue.
final surahsProvider = FutureProvider<List<Surah>>((ref) {
  return ref.watch(surahRepositoryProvider).getSurahs();
});

/// Search and filter state for the catalogue.
class SurahCatalogState {
  const SurahCatalogState({this.query = '', this.filter = SurahFilter.all});

  final String query;
  final SurahFilter filter;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty || filter != SurahFilter.all;

  SurahCatalogState copyWith({String? query, SurahFilter? filter}) {
    return SurahCatalogState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SurahCatalogState &&
            query == other.query &&
            filter == other.filter;
  }

  @override
  int get hashCode => Object.hash(query, filter);
}

class SurahCatalogController extends Notifier<SurahCatalogState> {
  @override
  SurahCatalogState build() => const SurahCatalogState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setFilter(SurahFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void clear() {
    state = const SurahCatalogState();
  }
}

final surahCatalogControllerProvider =
    NotifierProvider<SurahCatalogController, SurahCatalogState>(
      SurahCatalogController.new,
    );

/// The catalogue after applying the current search query and filter.
final filteredSurahsProvider = Provider<AsyncValue<List<Surah>>>((ref) {
  final surahs = ref.watch(surahsProvider);
  final query = ref.watch(
    surahCatalogControllerProvider.select((state) => state.query),
  );
  final filter = ref.watch(
    surahCatalogControllerProvider.select((state) => state.filter),
  );

  return surahs.whenData(
    (items) => searchSurahs(items, query: query, filter: filter),
  );
});

class SelectedSurahController extends Notifier<int?> {
  @override
  int? build() => null;

  /// Selects [number] without toggling an existing selection off.
  void select(int number) {
    state = number;
  }

  void toggle(int number) {
    state = state == number ? null : number;
  }

  void clear() {
    state = null;
  }
}

/// The selected Surah number, or null when nothing is selected.
final selectedSurahNumberProvider =
    NotifierProvider<SelectedSurahController, int?>(
      SelectedSurahController.new,
    );

/// Looks up a Surah by its Mushaf number.
final surahByNumberProvider = Provider.family<Surah?, int>((ref, number) {
  final surahs = ref.watch(surahsProvider).value;
  if (surahs == null) {
    return null;
  }

  for (final surah in surahs) {
    if (surah.number == number) {
      return surah;
    }
  }
  return null;
});

/// The full metadata for the selected Surah, if available.
final selectedSurahProvider = Provider<Surah?>((ref) {
  final selectedNumber = ref.watch(selectedSurahNumberProvider);
  if (selectedNumber == null) {
    return null;
  }
  return ref.watch(surahByNumberProvider(selectedNumber));
});
