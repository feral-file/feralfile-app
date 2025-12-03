import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_state.dart';
import 'package:autonomy_flutter/util/log.dart';

class BluetoothConnectBloc
    extends AuBloc<BluetoothConnectEvent, BluetoothConnectState> {
  BluetoothConnectBloc() : super(BluetoothConnectState()) {
    on<BluetoothConnectEventUpdateBluetoothState>((event, emit) async {
      emit(state.copyWith(bluetoothAdapterState: event.bluetoothAdapterState));
    });
  }

  @override
  void add(BluetoothConnectEvent event) {
    if (eventNotBetaTester.contains(event.runtimeType)) {
      super.add(event);
    } else {
      log.info(
        'BluetoothConnectBloc user is not beta tester, '
        'ignoring event ${event.runtimeType}',
      );
    }
  }
}

const eventNotBetaTester = [
  BluetoothConnectEventUpdateBluetoothState,
];
