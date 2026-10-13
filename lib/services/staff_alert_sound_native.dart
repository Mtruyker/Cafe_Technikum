import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class StaffAlertSound {
  bool get supported =>
      defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;
  Future<bool> play() async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return false;
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
      return true;
    } catch (_) {
      return false;
    }
  }
}
