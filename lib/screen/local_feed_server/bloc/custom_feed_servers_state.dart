import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:equatable/equatable.dart';

class CustomFeedServersState extends Equatable {
  const CustomFeedServersState({
    this.feedServices = const [],
    this.isLoading = false,
  });

  final List<BaseDP1FeedServiceImpl> feedServices;
  final bool isLoading;

  CustomFeedServersState copyWith({
    List<BaseDP1FeedServiceImpl>? feedServices,
    bool? isLoading,
  }) =>
      CustomFeedServersState(
        feedServices: feedServices ?? this.feedServices,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [feedServices, isLoading];
}
