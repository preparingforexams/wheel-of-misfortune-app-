import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:sensors_plus/sensors_plus.dart';

abstract class _MisfortuneEvent {}

class SpinEvent implements _MisfortuneEvent {}

class _AccelEvent implements _MisfortuneEvent {
  final UserAccelerometerEvent event;

  _AccelEvent(this.event);
}

enum Stage {
  awaitingSpin,
  spinning,
  failed,
}

class MisfortuneState {
  final Stage stage;
  final String? movement;

  const MisfortuneState._({
    required this.stage,
    this.movement,
  });

  MisfortuneState.initial() : this._(stage: Stage.awaitingSpin);

  MisfortuneState spinning() {
    return const MisfortuneState._(stage: Stage.spinning);
  }

  MisfortuneState failed() {
    return const MisfortuneState._(stage: Stage.failed);
  }

  MisfortuneState moved(double speed) {
    return MisfortuneState._(stage: stage, movement: speed.toString());
  }
}

class MisfortuneBloc extends Bloc<_MisfortuneEvent, MisfortuneState> {
  final MisfortuneClient _client;

  MisfortuneBloc(this._client) : super(MisfortuneState.initial()) {
    on<SpinEvent>(_spin);
    on<_AccelEvent>(_accel);
    userAccelerometerEvents.listen((event) => add(_AccelEvent(event)));
  }

  FutureOr<void> _spin(
    SpinEvent event,
    Emitter<MisfortuneState> emit,
  ) async {
    final result = await _client.spin();
    if (result) {
      emit(state.spinning());
    } else {
      emit(state.failed());
    }
  }

  double norm(double a, double b, double c) {
    return sqrt(pow(a, 2) + pow(b, 2) + pow(c, 2));
  }

  FutureOr<void> _accel(_AccelEvent event, Emitter<MisfortuneState> emit) {
    final accel = event.event;
    final length = norm(accel.x, accel.y, accel.z);
    print("length: $length");
  }
}
