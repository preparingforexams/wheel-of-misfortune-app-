import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:sensors_plus/sensors_plus.dart';

abstract class _MisfortuneEvent {}

class PressButtonEvent implements _MisfortuneEvent {}

class ScanQrEvent implements _MisfortuneEvent {
  final String code;

  ScanQrEvent(this.code);
}

class _AccelEvent implements _MisfortuneEvent {
  final UserAccelerometerEvent event;

  _AccelEvent(this.event);
}

enum Stage {
  awaitingPress,
  scanningCode,
  awaitingSpin,
  spinning,
  failed,
}

class MisfortuneState {
  final Stage stage;
  final bool tooSlow;
  final String? movement;
  final String? code;

  const MisfortuneState._({
    required this.stage,
    required this.tooSlow,
    this.movement,
    this.code,
  });

  factory MisfortuneState.initial(String? code) {
    if (code == null) {
      return const MisfortuneState._(
        stage: Stage.awaitingPress,
        tooSlow: false,
      );
    } else {
      return MisfortuneState._(
        stage: Stage.awaitingSpin,
        tooSlow: false,
        code: code,
      );
    }
  }

  MisfortuneState copy({
    Stage? stage,
    bool? tooSlow,
    required String? movement,
    required String? code,
  }) {
    return MisfortuneState._(
      stage: stage ?? this.stage,
      tooSlow: tooSlow ?? this.tooSlow,
      movement: movement,
      code: code,
    );
  }

  MisfortuneState failed(double speed) {
    return copy(
      stage: Stage.failed,
      tooSlow: false,
      movement: speed.toString(),
      code: null,
    );
  }

  MisfortuneState awaitPress() {
    return copy(
      stage: Stage.awaitingPress,
      tooSlow: false,
      movement: null,
      code: null,
    );
  }

  MisfortuneState awaitCode() {
    return const MisfortuneState._(
      stage: Stage.scanningCode,
      tooSlow: false,
      code: null,
      movement: null,
    );
  }

  MisfortuneState awaitSpin({
    required bool tooSlow,
    required double? speed,
    String? code,
  }) {
    return copy(
      stage: Stage.awaitingSpin,
      tooSlow: tooSlow,
      movement: speed?.toString(),
      code: code ?? this.code,
    );
  }

  MisfortuneState spinning(double speed) {
    return copy(
      stage: Stage.spinning,
      tooSlow: false,
      movement: speed.toString(),
      code: code,
    );
  }
}

class MisfortuneBloc extends Bloc<_MisfortuneEvent, MisfortuneState> {
  final MisfortuneClient _client;
  StreamSubscription? _subscription;

  MisfortuneBloc({
    required MisfortuneClient client,
    required String? code,
  })  : _client = client,
        super(MisfortuneState.initial(code)) {
    if (code != null) {
      _subscribe();
    }
    on<_AccelEvent>(_accel);
    on<PressButtonEvent>(_pressButton);
    on<ScanQrEvent>(_scanQr);
  }

  double norm({required double x, required double y}) {
    return sqrt(pow(x, 2) + pow(y, 2));
  }

  FutureOr<void> _accel(
    _AccelEvent event,
    Emitter<MisfortuneState> emit,
  ) async {
    if (state.stage != Stage.awaitingSpin) {
      return;
    }
    final accel = event.event;
    final length = norm(
      x: accel.x,
      y: accel.y,
    );
    if (length < 15) {
      if (length > 5) {
        emit(state.awaitSpin(tooSlow: true, speed: length));
      }
      return;
    }
    final result = await _client.spin(code: state.code!, speed: length);
    if (result) {
      emit(state.spinning(length));
    } else {
      emit(state.failed(length));
    }
    _subscription?.cancel();
    await Future.delayed(const Duration(seconds: 5));
    emit(state.awaitPress());
  }

  void _subscribe() {
    _subscription = userAccelerometerEvents.listen(
      (event) => add(_AccelEvent(event)),
    );
  }

  FutureOr<void> _scanQr(
    ScanQrEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    _subscribe();
    emit(state.awaitSpin(tooSlow: false, speed: null, code: event.code));
  }

  FutureOr<void> _pressButton(
    PressButtonEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    emit(state.awaitCode());
  }
}
