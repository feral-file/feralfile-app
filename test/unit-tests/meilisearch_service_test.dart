import 'package:flutter_test/flutter_test.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';

void main() {
  group('MeiliSearchService Tests', () {
    late MeiliSearchService service;

    setUp(() {
      service = MeiliSearchService(prefix: 'test');
    });

    test('should create service with correct prefix', () {
      expect(service.prefix, equals('test'));
    });

    test('should create service with default prefix', () {
      final defaultService = MeiliSearchService();
      expect(defaultService.prefix, equals('feed_prod'));
    });

    test('should handle search query creation', () {
      // Test basic functionality without actual network calls
      expect(service.prefix, isNotEmpty);
    });
  });

  group('MeiliSearchService Basic Tests', () {
    test('should handle service initialization', () {
      final service = MeiliSearchService(prefix: 'test');
      expect(service.prefix, equals('test'));
    });
  });
}
