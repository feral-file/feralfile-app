import 'dart:async';

import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';

class IndexerClient {
  IndexerClient(
    this._baseUrl, {
    AuthService? authService,
    Future<String> Function()? getTokenOverride,
  })  : _authService = authService,
        _getTokenOverride = getTokenOverride,
        _httpClient = http.Client();

  final String _baseUrl;
  final AuthService? _authService;
  final http.Client _httpClient;
  final Future<String> Function()? _getTokenOverride;

  // Reusable base HttpLink to avoid creating new connections
  HttpLink? _baseHttpLink;
  // Reusable base GraphQLClient for non-authenticated requests
  GraphQLClient? _baseClient;
  // Reusable authenticated GraphQLClient
  GraphQLClient? _authenticatedClient;

  /// Dispose resources. Call this when IndexerClient is no longer needed.
  void dispose() {
    _httpClient.close();
    _baseHttpLink = null;
    _baseClient = null;
    _authenticatedClient = null;
  }

  HttpLink _getBaseHttpLink() {
    return _baseHttpLink ??= HttpLink(
      '$_baseUrl/graphql',
      httpClient: _httpClient,
    );
  }

  GraphQLClient getClient() {
    return _baseClient ??= _createBaseClient();
  }

  GraphQLClient _createBaseClient() {
    final httpLink = _getBaseHttpLink();

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: httpLink,
    );
  }

  Future<dynamic> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
    String? subKey,
  }) async {
    try {
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
        // Always fetch from network to avoid stale cache
        fetchPolicy: FetchPolicy.networkOnly,
      );

      NftCollection.logger.info('Querying: $doc with params: $vars');

      final result =
          await getClient().query(options).timeout(Duration(seconds: 60));
      if (result.hasException) {
        NftCollection.logger
            .info('Error when querying: $doc with params: $vars');
        NftCollection.logger.warning(
          'GraphQL query exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
        );
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage(
            'GraphQL query exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
          ),
          level: SentryLevel.error,
          tags: {
            'doc': doc,
            'vars': vars.toString(),
          },
          throwable: result.exception,
        ));
        throw Exception('Error querying: ${result.exception?.raw}');
      }
      if (subKey != null) {
        return result.data?[subKey];
      }
      return result.data;
    } catch (e) {
      NftCollection.logger.info('Error querying: $e');
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error querying: $e'),
        level: SentryLevel.error,
        extra: {
          'doc': doc,
          'vars': vars.toString(),
        },
      ));
      throw Exception('Error querying: $e');
    }
  }

  Future<dynamic> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
  }) async {
    try {
      // Create a new client with auth if token is needed
      final clientToUse =
          withToken ? _createAuthenticatedClient() : getClient();

      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
        queryRequestTimeout: Duration(seconds: 10),
        fetchPolicy: FetchPolicy.networkOnly,
        onError: (e) {
          NftCollection.logger.warning(
            '[IndexerClient][Link] Error: $e',
          );

          Sentry.captureEvent(SentryEvent(
            message: SentryMessage('Error mutating: $e'),
            extra: {
              'doc': doc,
              'vars': vars.toString(),
            },
            level: SentryLevel.error,
          ));
          throw Exception('Error mutating: $e');
        },
      );

      NftCollection.logger.info('Mutating: $doc with params: $vars');
      final result =
          await clientToUse.mutate(options).timeout(Duration(seconds: 15));
      if (result.exception != null) {
        NftCollection.logger.info('Error mutating: $doc with params: $vars');
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage(
            'GraphQL mutation exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
          ),
          level: SentryLevel.error,
          tags: {
            'doc': doc,
            'vars': vars.toString(),
          },
          throwable: result.exception,
        ));
        throw Exception('Error mutating: ${result.exception?.raw}');
      }
      return result.data;
    } catch (e) {
      NftCollection.logger.info('Error mutating: $e');
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error mutating: $e'),
        level: SentryLevel.error,
        extra: {
          'doc': doc,
          'vars': vars.toString(),
        },
      ));
      throw Exception('Error mutating: $e');
    }
  }

  GraphQLClient _createAuthenticatedClient() {
    return _authenticatedClient ??= _createBaseAuthenticatedClient();
  }

  GraphQLClient _createBaseAuthenticatedClient() {
    final authLink = AuthLink(getToken: _getToken);
    final baseClient = _createBaseClient();
    final baseLink = baseClient.link;
    final link = authLink.concat(baseLink);
    return baseClient.copyWith(link: link);
  }

  Future<String> _getToken() async {
    try {
      if (_getTokenOverride != null) {
        final authToken = await _getTokenOverride();
        NftCollection.logger
            .info('IndexerClient: getToken ${authToken.substring(0, 10)}');
        return authToken;
      }
      if (_authService == null) return '';
      final jwt = await _authService.getAuthToken();
      NftCollection.logger
          .info('IndexerClient: getToken ${jwt?.jwtToken.substring(0, 10)}');
      return jwt != null ? 'Bearer ${jwt.jwtToken}' : '';
    } catch (e) {
      NftCollection.logger.warning('Failed to get auth token: $e');
      return '';
    }
  }
}
