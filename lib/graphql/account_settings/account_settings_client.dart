import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class AccountSettingsClient {
  AccountSettingsClient(this._baseUrl);

  final String _baseUrl;

  GraphQLClient get client {
    final httpLink = HttpLink(_baseUrl);
    final authLink = AuthLink(getToken: _getToken);
    final link = authLink.concat(httpLink);

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: link,
    );
  }

  Future<List<Map<String, String>>> query({
    required Map<String, dynamic> vars,
  }) async {
    final data = await _query(doc: _queryDoc, vars: vars);
    final values = data?['keys']?['values'] as List<dynamic>? ?? [];
    log.info('AccountSettingsClient: query $values');
    final rawResult = values.cast<Map<String, dynamic>>();
    return rawResult
        .where((element) => element['value'] != null)
        .map((e) => Map<String, String>.from({
              'key': e['key'],
              'value': e['value'].toString(),
            }))
        .toList();
  }

  Future<dynamic> _query({
    required String doc,
    required Map<String, dynamic> vars,
  }) async {
    try {
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
      );

      final result = await client.query(options);
      return result.data;
    } catch (e) {
      log.info('AccountSettingsClient: query error $e');
      return null;
    }
  }

  Future<dynamic> _mutate({
    required String doc,
    required Map<String, dynamic> vars,
  }) async {
    try {
      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
      );

      final result = await client.mutate(options);
      final exception = result.exception;
      if (exception != null) {
        log.info('AccountSettingsClient: mutate exception $exception');
      }
      return result.data;
    } catch (e) {
      log.info('AccountSettingsClient: mutate error $e');
      return null;
    }
  }

  Future<bool> write({
    required List<Map<String, String>> data,
  }) async {
    if (data.isEmpty) {
      return true;
    }
    final resultData = await _mutate(doc: _writeDoc, vars: {'data': data});
    log
      ..info('AccountSettingsClient: write $data')
      ..info('AccountSettingsClient: write result ${resultData?['write']}');
    return (resultData?['write']?['ok'] ?? false) as bool;
  }

  Future<bool> delete({
    required Map<String, dynamic> vars,
  }) async {
    final data = await _mutate(doc: _deleteDoc, vars: vars);
    log.info('AccountSettingsClient: delete $data');
    return (data?['delete']?['ok'] ?? false) as bool;
  }

  Future<String> _getToken() async {
    final jwt = await injector<AuthService>().getAuthToken();
    log.info(
        'AccountSettingsClient: getToken ${jwt?.jwtToken.substring(0, 10)}');
    return 'Bearer ${jwt ?? ''}';
  }

  static const String _queryDoc = r'''
    query ($search: String, $keys: [String!], $cursor: String) {
      keys(search: $search, keys: $keys, cursor: $cursor) {
        values {
          key
          value
        }
        cursor
      }
    }
  ''';
  static const String _writeDoc = r'''
    mutation ($data: [KeyValueInput!]!) {
      write(data: $data) {
        ok
      }
    }
  ''';
  static const String _deleteDoc = r'''
    mutation ($search: String, $keys: [String!]) {
      delete(search: $search, keys: $keys) {
        ok
      }
    }
  ''';
}
