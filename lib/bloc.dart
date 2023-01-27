import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'motion.dart';

abstract class _MisfortuneEvent {}

class PressButtonEvent implements _MisfortuneEvent {
  const PressButtonEvent();
}

class ScanQrEvent implements _MisfortuneEvent {
  final String code;

  ScanQrEvent(this.code);
}

class PermissionResultEvent implements _MisfortuneEvent {
  final String? result;

  PermissionResultEvent(this.result);
}

class _AccelEvent implements _MisfortuneEvent {
  final MotionEvent event;

  _AccelEvent(this.event);
}

enum Stage {
  wrongBrowser,
  awaitingPermissions,
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
  final String? error;

  const MisfortuneState._({
    required this.stage,
    required this.tooSlow,
    this.movement,
    this.code,
    this.error,
  });

  factory MisfortuneState.initial(String? code) {
    final browser = Browser();
    // if (![
    //   BrowserAgent.Chrome,
    //   BrowserAgent.EdgeChromium,
    //   BrowserAgent.Safari,
    // ].contains(browser.browserAgent)) {
    //   return const MisfortuneState._(
    //     stage: Stage.wrongBrowser,
    //     tooSlow: false,
    //     movement: null,
    //   );
    // }

    if (browser.browserAgent == BrowserAgent.Safari) {
      return MisfortuneState._(
        stage: Stage.awaitingPermissions,
        tooSlow: false,
        code: code,
      );
    } else if (code == null) {
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
    required String? error,
  }) {
    return MisfortuneState._(
      stage: stage ?? this.stage,
      tooSlow: tooSlow ?? this.tooSlow,
      movement: movement,
      code: code,
      error: error,
    );
  }

  MisfortuneState permissionGranted() {
    if (code != null) {
      return copy(
        stage: Stage.awaitingSpin,
        movement: movement,
        code: code,
        error: error,
      );
    } else {
      return copy(
        stage: Stage.awaitingPress,
        movement: movement,
        code: code,
        error: error,
      );
    }
  }

  MisfortuneState failed(double speed, String error) {
    return copy(
      stage: Stage.failed,
      tooSlow: false,
      movement: speed.toString(),
      code: null,
      error: error,
    );
  }

  MisfortuneState awaitPress() {
    return copy(
      stage: Stage.awaitingPress,
      tooSlow: false,
      movement: null,
      code: null,
      error: null,
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
    String? movement,
  }) {
    return copy(
      stage: Stage.awaitingSpin,
      tooSlow: tooSlow,
      movement: movement ?? speed?.toString(),
      code: code ?? this.code,
      error: null,
    );
  }

  MisfortuneState spinning(double speed) {
    return copy(
      stage: Stage.spinning,
      tooSlow: false,
      movement: speed.toString(),
      code: code,
      error: null,
    );
  }
}

class MisfortuneBloc extends Bloc<_MisfortuneEvent, MisfortuneState> {
  final MisfortuneClient _client;
  StreamSubscription? _subscription;
  DateTime? _lastSuccessfulSpin;

  MisfortuneBloc({
    required MisfortuneClient client,
    required String? code,
  })  : _client = client,
        super(MisfortuneState.initial(code)) {
    if (code != null) {
      _subscribe();
    }
    on<_AccelEvent>(_accel);
    on<PermissionResultEvent>(_receivedPermissionResult);
    on<PressButtonEvent>(_pressButton);
    on<ScanQrEvent>(_scanQr);
  }

  double generalNorm(List<double> axes) {
    double sum = 0;
    for (final axis in axes) {
      sum += pow(axis, 2);
    }
    final result = pow(sum, 1 / axes.length);
    return result.toDouble();
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
    final now = DateTime.now();
    final lastSuccessfulSpin = _lastSuccessfulSpin;

    if (lastSuccessfulSpin != null &&
        now.difference(lastSuccessfulSpin).inSeconds < 5) {
      return;
    }

    final accel = event.event;

    final speed = accel.x.abs();

    if (speed < 20) {
      if (speed > 5) {
        emit(state.awaitSpin(tooSlow: true, speed: speed));
      }
      return;
    }

    _lastSuccessfulSpin = now;

    try {
      final result = await _client.spin(code: state.code!, speed: speed);
      if (result) {
        emit(state.spinning(speed));
      } else {
        emit(state.failed(speed, "Jemand anderes war schneller"));
      }
    } on Exception catch (e) {
      emit(state.failed(speed, e.toString()));
    }

    _subscription?.cancel();
    await Future.delayed(const Duration(seconds: 5));
    emit(state.awaitPress());
  }

  void _subscribe() {
    _subscription = Motion.subscribe(
      (event) => add(_AccelEvent(event)),
    );
  }

  FutureOr<void> _receivedPermissionResult(
    PermissionResultEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    if (event.result == "granted") {
      emit(state.permissionGranted());
    } else {
      emit(state.copy(
        movement: null,
        code: null,
        error: "Did not get permission: ${event.result}",
      ));
    }
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
