import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home_state.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';

abstract class FeralFileHomeEvent {}

class FeralFileHomeFetchDataEvent extends FeralFileHomeEvent {}

class FeralfileHomeBloc
    extends AuBloc<FeralFileHomeEvent, FeralfileHomeBlocState> {
  FeralfileHomeBloc(this._feralFileService) : super(FeralfileHomeBlocState()) {
    on<FeralFileHomeFetchDataEvent>((event, emit) async {
      final statistics = await _feralFileService.getExploreStatistics();
      final featuredWorks = await _feralFileService.getFeaturedArtworks();

      emit(FeralfileHomeBlocState(
        exploreStatisticsData: statistics,
        featuredArtworks: featuredWorks,
      ));
    });
  }
  final FeralFileService _feralFileService;
}
