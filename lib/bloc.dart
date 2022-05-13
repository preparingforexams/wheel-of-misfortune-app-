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
  final bool tooSlow;
  final String? movement;

  const MisfortuneState._({
    required this.stage,
    required this.tooSlow,
    this.movement,
  });

  MisfortuneState.initial()
      : this._(
          stage: Stage.awaitingPress,
          tooSlow: false,
        );

  MisfortuneState failed(double speed) {
    return MisfortuneState._(
      stage: Stage.failed,
      tooSlow: false,
      movement: speed.toString(),
    );
  }

  MisfortuneState awaitPress() {
    return const MisfortuneState._(
      stage: Stage.awaitingPress,
      tooSlow: false,
    );
  }

  MisfortuneState awaitSpin({
    required bool tooSlow,
    required double? speed,
  }) {
    return MisfortuneState._(
      stage: Stage.awaitingSpin,
      tooSlow: tooSlow,
      movement: speed?.toString(),
    );
  }

  MisfortuneState spinning(double speed) {
    return MisfortuneState._(
      stage: Stage.spinning,
      tooSlow: false,
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

  double norm({required double x, required double y}) {
    return sqrt(pow(x, 2) + pow(y, 2));
  }

  FutureOr<void> _accel(
    _AccelEvent event,
    Emitter<MisfortuneState> emit,
  ) async {
    final accel = event.event;
    final length = norm(
      x: accel.x,
      y: accel.y,
    );
    if (length < 20) {
      if (length > 5) emit(state.awaitSpin(tooSlow: true, speed: length));
      return;
    }
    _subscription?.cancel();
    final result = await _client.spin();
    if (result) {
      emit(state.spinning(length));
    } else {
      emit(state.failed(length));
    }
    await Future.delayed(const Duration(seconds: 5));
    emit(state.awaitPress());
  }

  FutureOr<void> _sub(
    SubscribeEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    _subscription = userAccelerometerEvents.listen(
      (event) => add(_AccelEvent(event)),
    );
    emit(state.awaitSpin(tooSlow: false, speed: null));
  }
}
