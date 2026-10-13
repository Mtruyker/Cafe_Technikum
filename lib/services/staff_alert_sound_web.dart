import 'dart:js_interop';

@JS('techCafeStaffSound')
external JSPromise<JSBoolean> _playSound();

class StaffAlertSound {
  bool get supported => true;
  Future<bool> play() async {
    try {
      return (await _playSound().toDart.timeout(
        const Duration(seconds: 3),
      )).toDart;
    } catch (_) {
      return false;
    }
  }
}
