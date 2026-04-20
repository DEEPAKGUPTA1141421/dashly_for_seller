import 'package:flutter/services.dart';

class SoundUtils {
  static void tap() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  static void select() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void add() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  static void remove() {
    HapticFeedback.lightImpact();
  }

  static void error() {
    HapticFeedback.vibrate();
  }
}
