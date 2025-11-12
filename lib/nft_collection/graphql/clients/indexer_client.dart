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
        _getTokenOverride = getTokenOverride;

  final String _baseUrl;
  final AuthService? _authService;
  final Future<String> Function()? _getTokenOverride;

  GraphQLClient getClient({
    void Function(Object error, StackTrace? stackTrace)? onError,
    FutureOr<http.StreamedResponse> Function()? onTimeout,
  }) {
    final httpLink = HttpLink(
      '$_baseUrl/graphql',
      httpClient: _TimeoutHttpClient(
          http.Client(), const Duration(seconds: 60), onTimeout),
    );
    // Default client without auth; wrap with error handler link by default
    final defaultOnError = onError ??
        (Object error, StackTrace? stackTrace) {
          NftCollection.logger.warning(
            '[IndexerClient][Link] Error: $error\nStackTrace: $stackTrace',
          );
        };
    final link = _ErrorHandlerLink(onError: defaultOnError).concat(httpLink);

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
    try {
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
        // Avoid short implicit timeouts by keeping logic in links; allow cache if needed
        // fetchPolicy: FetchPolicy.networkOnly,
      );

      final onError = (Object error, StackTrace? stackTrace) {
        NftCollection.logger.warning(
          '[IndexerClient][Link] Error: $error\nStackTrace: $stackTrace',
        );
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage('Error querying: $error'),
          level: SentryLevel.error,
          extra: {
            'doc': doc,
            'vars': vars.toString(),
          },
        ));
        throw error;
      };

      NftCollection.logger.info('Querying: $doc with params: $vars');

      final result = await getClient(onError: onError)
          .query(options)
          .timeout(Duration(seconds: 60));
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
      return null;
    }
  }

  Future<dynamic> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
    void Function(Object error, StackTrace? stackTrace)? onError,
  }) async {
    try {
      final onError = (Object error, StackTrace? stackTrace) {
        NftCollection.logger.warning(
          '[IndexerClient][Link] Error: $error\nStackTrace: $stackTrace',
        );
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage('Error mutating: $error'),
          level: SentryLevel.error,
        ));
        throw error;
      };

      final onTimeout = () {
        NftCollection.logger
            .warning('Timeout mutating: $doc with params: $vars');
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage('Timeout mutating: $doc with params: $vars'),
          level: SentryLevel.error,
        ));
        throw TimeoutException('Timeout');
      };

      // Create a new client with auth if token is needed
      final clientToUse = withToken
          ? _createAuthenticatedClient(onError: onError, onTimeout: onTimeout)
          : getClient(onError: onError, onTimeout: onTimeout);

      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
        queryRequestTimeout: Duration(seconds: 60),
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
        },
      );

      NftCollection.logger.info('Mutating: $doc with params: $vars');
      final result = await clientToUse.mutate(options);
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
        // Call onError callback if provided
        if (onError != null) {
          final stackTrace = result.exception?.linkException is Exception
              ? StackTrace.current
              : null;
          onError(result.exception!, stackTrace);
        }
      }
      return result.data;
    } catch (e, stackTrace) {
      NftCollection.logger.info('Error mutating: $e');
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error mutating: $e'),
        level: SentryLevel.error,
        extra: {
          'doc': doc,
          'vars': vars.toString(),
        },
      ));
      // Call onError callback if provided
      if (onError != null) {
        onError(e, stackTrace);
      }
    }
  }

  GraphQLClient _createAuthenticatedClient({
    void Function(Object error, StackTrace? stackTrace)? onError,
    FutureOr<http.StreamedResponse> Function()? onTimeout,
  }) {
    final authLink = AuthLink(getToken: _getToken);
    final baseClient = getClient(onError: onError, onTimeout: onTimeout);
    final baseLink = baseClient.link;
    final link = authLink.concat(baseLink);
    final clientWithAuth = baseClient.copyWith(link: link);
    return clientWithAuth;
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

/// Custom Link to handle errors and call onError callback
class _ErrorHandlerLink extends Link {
  _ErrorHandlerLink({required this.onError});

  final void Function(Object error, StackTrace? stackTrace) onError;

  @override
  Stream<Response> request(
    Request request, [
    NextLink? forward,
  ]) async* {
    try {
      yield* forward!(request);
    } catch (e, stackTrace) {
      onError(e, stackTrace);
      rethrow;
    }
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this.timeout, this.onTimeout);

  final http.Client _inner;
  final Duration timeout;
  final FutureOr<http.StreamedResponse> Function()? onTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout, onTimeout: onTimeout);
  }

  @override
  void close() {
    _inner.close();
  }
}
