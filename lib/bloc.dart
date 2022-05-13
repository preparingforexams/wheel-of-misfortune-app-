import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:sensors_plus/sensors_plus.dart';

abstract class _MisfortuneEvent {}

class SubscribeEvent implements _MisfortuneEvent {}

class _AccelEvent implements _MisfortuneEvent {
  final UserAccelerometerEvent event;

  _AccelEvent(this.event);
}

enum Stage {
  awaitingPress,
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

  MisfortuneState.initial() : this._(stage: Stage.awaitingPress);

  MisfortuneState failed(double speed) {
    return MisfortuneState._(
      stage: Stage.failed,
      movement: speed.toString(),
    );
  }

  MisfortuneState awaitPress() {
    return const MisfortuneState._(stage: Stage.awaitingPress);
  }

  MisfortuneState awaitSpin() {
    return const MisfortuneState._(stage: Stage.awaitingSpin);
  }

  MisfortuneState spinning(double speed) {
    return MisfortuneState._(
      stage: Stage.spinning,
      movement: speed.toString(),
    );
  }
}

class MisfortuneBloc extends Bloc<_MisfortuneEvent, MisfortuneState> {
  final MisfortuneClient _client;
  StreamSubscription? _subscription;

  MisfortuneBloc(this._client) : super(MisfortuneState.initial()) {
    on<_AccelEvent>(_accel);
    on<SubscribeEvent>(_sub);
  }

  double norm(double a, double b, double c) {
    return sqrt(pow(a, 2) + pow(b, 2) + pow(c, 2));
  }

  FutureOr<void> _accel(
    _AccelEvent event,
    Emitter<MisfortuneState> emit,
  ) async {
    final accel = event.event;
    final length = norm(accel.x, accel.y, accel.z);
    _subscription?.cancel();
    final result = await _client.spin();
    if (result) {
      emit(state.spinning(length));
    } else {
      emit(state.failed(length));
    }
    await Future.delayed(const Duration(seconds: 5));
    emit(state.awaitSpin());
  }

  FutureOr<void> _sub(
    SubscribeEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    _subscription = userAccelerometerEvents.listen(
      (event) => add(_AccelEvent(event)),
    );
    emit(state.awaitSpin());
  }
}
