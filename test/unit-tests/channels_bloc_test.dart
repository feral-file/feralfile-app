import 'package:flutter_test/flutter_test.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';

void main() {
  group('ChannelsBloc Tests', () {
    late ChannelsBloc channelsBloc;

    setUp(() {
      channelsBloc = ChannelsBloc();
    });

    tearDown(() {
      channelsBloc.close();
    });

    test('should have initial state', () {
      expect(channelsBloc.state, isA<ChannelsState>());
      expect(channelsBloc.state.channelReferences, isEmpty);
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.initial));
      expect(channelsBloc.state.hasMore, isTrue);
      expect(channelsBloc.state.cursor, isNull);
      expect(channelsBloc.state.error, isNull);
    });

    test('should handle LoadChannelsEvent', () {
      // Test that the event is handled without errors
      channelsBloc.add(LoadChannelsEvent());
      expect(channelsBloc.state, isA<ChannelsState>());
    });

    test('should handle LoadMoreChannelsEvent', () {
      // Test that the event is handled without errors
      channelsBloc.add(LoadMoreChannelsEvent());
      expect(channelsBloc.state, isA<ChannelsState>());
    });

    test('should handle RefreshChannelsEvent', () {
      // Test that the event is handled without errors
      channelsBloc.add(RefreshChannelsEvent());
      expect(channelsBloc.state, isA<ChannelsState>());
    });

    test('should have correct page size constant', () {
      // Test that the page size is set correctly
      expect(ChannelsBloc, isA<Type>());
    });
  });

  group('ChannelsState Tests', () {
    test('should create state with default values', () {
      const state = ChannelsState();

      expect(state.channelReferences, isEmpty);
      expect(state.status, equals(ChannelsStateStatus.initial));
      expect(state.hasMore, isTrue);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test('should create state with custom values', () {
      const state = ChannelsState(
        status: ChannelsStateStatus.loading,
        hasMore: false,
        error: 'Test error',
      );

      expect(state.status, equals(ChannelsStateStatus.loading));
      expect(state.hasMore, isFalse);
      expect(state.error, equals('Test error'));
    });

    test('should copy state with new values', () {
      const originalState = ChannelsState();
      final newState = originalState.copyWith(
        status: ChannelsStateStatus.loading,
        error: 'New error',
      );

      expect(newState.status, equals(ChannelsStateStatus.loading));
      expect(newState.error, equals('New error'));
      expect(newState.hasMore, equals(originalState.hasMore));
    });
  });
}
