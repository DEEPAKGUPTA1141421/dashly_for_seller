import 'package:flutter/services.dart';

class HapticUtils {
  static void light()    => HapticFeedback.lightImpact();
  static void medium()   => HapticFeedback.mediumImpact();
  static void heavy()    => HapticFeedback.heavyImpact();
  static void success()  => HapticFeedback.selectionClick();
  static void vibrate()  => HapticFeedback.vibrate();
}
