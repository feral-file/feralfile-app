import 'package:meilisearch/meilisearch.dart';
import 'package:mocktail/mocktail.dart';

/// Mock for MeiliSearchClient using mocktail
class MockMeiliSearchClient extends Mock implements MeiliSearchClient {}

/// Mock for SearchResult using mocktail
class MockSearchResult extends Mock
    implements SearchResult<Map<String, dynamic>> {}

/// Mock for MultiSearchResult using mocktail
class MockMultiSearchResult extends Mock implements MultiSearchResult {}

/// Mock for MultiSearchQuery using mocktail
class MockMultiSearchQuery extends Mock implements MultiSearchQuery {}

/// Mock for SearchQuery using mocktail
class MockSearchQuery extends Mock implements SearchQuery {}

/// Mock for Searchable using mocktail
class MockSearchable<T> extends Mock implements Searcheable<T> {}
