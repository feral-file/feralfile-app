import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'custom_feed_servers_event.dart';
import 'custom_feed_servers_state.dart';

class CustomFeedServersBloc
    extends AuBloc<CustomFeedServersEvent, CustomFeedServersState> {
  CustomFeedServersBloc() : super(const CustomFeedServersState()) {
    on<LoadCustomFeedServersEvent>(_onLoad);
    on<RefreshCustomFeedServersEvent>(_onRefresh);
    on<RemoveCustomFeedServerEvent>(_onRemove);
  }

  Future<void> _onLoad(
    LoadCustomFeedServersEvent event,
    Emitter<CustomFeedServersState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final urls = injector<AppDataManager>()
        .dp1FeedStorageService
        .getCustomFeedServersByUrls();
    final feedServices = urls
        .map((url) => injector<FeralFileFeedManager>().getFeedServiceByUrl(url))
        .nonNulls
        .toList();
    emit(state.copyWith(feedServices: feedServices, isLoading: false));
  }

  Future<void> _onRefresh(
    RefreshCustomFeedServersEvent event,
    Emitter<CustomFeedServersState> emit,
  ) async {
    final urls = injector<AppDataManager>()
        .dp1FeedStorageService
        .getCustomFeedServersByUrls();
    final feedServices = urls
        .map((url) => injector<FeralFileFeedManager>().getFeedServiceByUrl(url))
        .nonNulls
        .toList();
    emit(state.copyWith(feedServices: feedServices));
  }

  Future<void> _onRemove(
    RemoveCustomFeedServerEvent event,
    Emitter<CustomFeedServersState> emit,
  ) async {
    final url = event.url;
    // Remove from in-memory manager
    injector<FeralFileFeedManager>().removeFeedServiceByUrl(url);
    // Remove from local settings
    await injector<AppDataManager>()
        .dp1FeedStorageService
        .deleteCustomFeedServersByUrls([url]);
    // Refresh list
    final urls = injector<AppDataManager>()
        .dp1FeedStorageService
        .getCustomFeedServersByUrls();
    final feedServices = urls
        .map((url) => injector<FeralFileFeedManager>().getFeedServiceByUrl(url))
        .nonNulls
        .toList();
    emit(state.copyWith(feedServices: feedServices));
  }
}
