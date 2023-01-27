@JS()
library safari_permissions;

import 'package:js/js.dart';

external void requestDeviceMotionEventPermission(
  void Function(String?) callback,
);
