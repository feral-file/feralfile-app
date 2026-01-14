// // GENERATED CODE - DO NOT MODIFY BY HAND

// part of 'tzkt_api.dart';

// // **************************************************************************
// // RetrofitGenerator
// // **************************************************************************

// // ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers

// class _TZKTApi implements TZKTApi {
//   _TZKTApi(
//     this._dio, {
//     this.baseUrl,
//   }) {
//     baseUrl ??= 'https://api.tzkt.io';
//   }

//   final Dio _dio;

//   String? baseUrl;

//   @override
//   Future<List<TZKTTokenTransfer>> getTokenTransfer({
//     String? anyOf,
//     String? to,
//     String sort = "id",
//     int? limit,
//     int? lastId,
//     String? lastTime,
//   }) async {
//     const _extra = <String, dynamic>{};
//     final queryParameters = <String, dynamic>{
//       r'anyof.from.to': anyOf,
//       r'to': to,
//       r'sort.desc': sort,
//       r'limit': limit,
//       r'lastId': lastId,
//       r'timestamp.gt': lastTime,
//     };
//     queryParameters.removeWhere((k, v) => v == null);
//     final _headers = <String, dynamic>{};
//     final Map<String, dynamic>? _data = null;
//     final _result = await _dio
//         .fetch<List<dynamic>>(_setStreamType<List<TZKTTokenTransfer>>(Options(
//       method: 'GET',
//       headers: _headers,
//       extra: _extra,
//     )
//             .compose(
//               _dio.options,
//               '/v1/tokens/transfers',
//               queryParameters: queryParameters,
//               data: _data,
//             )
//             .copyWith(
//                 baseUrl: _combineBaseUrls(
//               _dio.options.baseUrl,
//               baseUrl,
//             ))));
//     var value = _result.data!
//         .map((dynamic i) =>
//             TZKTTokenTransfer.fromJson(i as Map<String, dynamic>))
//         .toList();
//     return value;
//   }

//   RequestOptions _setStreamType<T>(RequestOptions requestOptions) {
//     if (T != dynamic &&
//         !(requestOptions.responseType == ResponseType.bytes ||
//             requestOptions.responseType == ResponseType.stream)) {
//       if (T == String) {
//         requestOptions.responseType = ResponseType.plain;
//       } else {
//         requestOptions.responseType = ResponseType.json;
//       }
//     }
//     return requestOptions;
//   }

//   String _combineBaseUrls(
//     String dioBaseUrl,
//     String? baseUrl,
//   ) {
//     if (baseUrl == null || baseUrl.trim().isEmpty) {
//       return dioBaseUrl;
//     }

//     final url = Uri.parse(baseUrl);

//     if (url.isAbsolute) {
//       return url.toString();
//     }

//     return Uri.parse(dioBaseUrl).resolveUri(url).toString();
//   }
// }
