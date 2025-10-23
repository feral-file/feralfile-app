import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
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
    final urls = injector<CloudManager>()
        .dp1FeedCloudObject
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
    final urls = injector<CloudManager>()
        .dp1FeedCloudObject
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
    // Remove from cloud
    await injector<CloudManager>()
        .dp1FeedCloudObject
        .deleteCustomFeedServersByUrls([url]);
    // Refresh list
    final urls = injector<CloudManager>()
        .dp1FeedCloudObject
        .getCustomFeedServersByUrls();
    final feedServices = urls
        .map((url) => injector<FeralFileFeedManager>().getFeedServiceByUrl(url))
        .nonNulls
        .toList();
    emit(state.copyWith(feedServices: feedServices));
  }
}
