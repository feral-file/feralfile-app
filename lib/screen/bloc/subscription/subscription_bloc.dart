import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/util/log.dart';

class SubscriptionBloc extends AuBloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc() : super(SubscriptionState()) {
    on<GetSubscriptionEvent>((event, emit) async {
      log.info('GetSubscriptionEvent');
      final isSubscribed = true;
      log.info('isSubscribed: $isSubscribed');
      emit(state.copyWith(
        isSubscribed: isSubscribed,
      ));
    });
  }
}
