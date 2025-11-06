import 'dart:async';

import 'package:autonomy_flutter/model/dp1/dp1_manifest.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Helper class for fetching DP1 manifests
class DP1ManifestHelper {
  DP1ManifestHelper._();

  static final DP1ManifestHelper _instance = DP1ManifestHelper._();
  static DP1ManifestHelper get instance => _instance;

  /// Fetch DP1 manifests from refs using batch processing
  ///
  /// This method fetches DP1 manifests from the provided refs in batches of 10
  /// to avoid overwhelming the server with too many concurrent requests.
  ///
  /// [refs] - List of manifest reference URLs to fetch
  ///
  /// Returns a Map where keys are the ref URLs and values are the corresponding DP1Manifest objects
  Future<Map<String, DP1Manifest>> fetchDP1Manifests(List<String> refs) async {
    if (refs.isEmpty) {
      return <String, DP1Manifest>{};
    }

    // Fetch DP1 manifests from refs, using dio (from dioManager)
    final dio = DioManager().base(BaseOptions());

    // Get by batch 10 items
    final manifests = <String, DP1Manifest>{};

    // Process refs in batches of 10
    for (int i = 0; i < refs.length; i += 10) {
      final batch = refs.skip(i).take(10).toList();
      final futures = batch.map((String ref) async {
        try {
          final res = await dio.get<Map<String, dynamic>>(ref);
          if (res.statusCode == 200 && res.data != null) {
            final manifest = DP1Manifest.fromJson(res.data!);
            manifests[ref] = manifest;
            return manifest;
          }
          throw Exception(
            'Failed to fetch DP1 manifest: ${res.statusCode}',
          );
        } catch (e) {
          log.info('Failed to fetch DP1 manifest: $e');
          unawaited(
            Sentry.captureException(
              'Failed to fetch DP1 manifest for ref: $ref, error: $e',
            ),
          );
          return manifests[ref];
        }
      });

      final results = await Future.wait<DP1Manifest?>(futures);
      for (final result in results) {
        if (result != null) {
          manifests[result.id] = result;
        }
      }
    }

    return manifests;
  }

  /// Fetch a single DP1 manifest from a ref URL
  ///
  /// [ref] - The manifest reference URL to fetch
  ///
  /// Returns the DP1Manifest object, or null if fetching fails
  Future<DP1Manifest?> fetchSingleDP1Manifest(String ref) async {
    try {
      final dio = DioManager().base(BaseOptions());
      final res = await dio.get<Map<String, dynamic>>(ref);

      if (res.statusCode == 200 && res.data != null) {
        return DP1Manifest.fromJson(res.data!);
      }

      log.info('Failed to fetch DP1 manifest: ${res.statusCode}');
      return null;
    } catch (e) {
      log.info('Failed to fetch DP1 manifest: $e');
      unawaited(
        Sentry.captureException(
          'Failed to fetch DP1 manifest for ref: $ref, error: $e',
        ),
      );
      return null;
    }
  }
}
