import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

class IndexerClient {
  IndexerClient(this._baseUrl);

  final String _baseUrl;

  GraphQLClient get client {
    final httpLink = HttpLink(
      '$_baseUrl/graphql',
      httpClient: _TimeoutHttpClient(
        http.Client(),
        const Duration(seconds: 5),
      ),
    );
    final authLink = AuthLink(getToken: _getToken);

    final link = authLink.concat(httpLink);

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: link,
    );
  }

  Future<dynamic> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
    String? subKey,
  }) async {
    return Map<String, dynamic>.from(
        mockdata); // Temporary mock data to avoid indexer issues
    try {
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
        // Avoid short implicit timeouts by keeping logic in links; allow cache if needed
        // fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.query(options);
      if (result.hasException) {
        NftCollection.logger.warning(
          'GraphQL query exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
        );
      }
      if (subKey != null) {
        return result.data?[subKey];
      }
      return result.data;
    } catch (e) {
      NftCollection.logger.info('Error querying: $e');
      return null;
    }
  }

  Future<dynamic> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
  }) async {
    try {
      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
      );

      final result = await client.mutate(options);
      return result.data;
    } catch (e) {
      return null;
    }
  }

  Future<String> _getToken() async {
    return '';
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this.timeout);

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}
