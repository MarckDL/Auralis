import 'dart:async';

import 'package:flutter/foundation.dart';

import 'player_controller.dart';

enum SleepTimerMode { inactive, duration, endOfSong }

class SleepTimerController extends ChangeNotifier {
  SleepTimerController({required this.playerController});

  final PlayerController playerController;
  Timer? _timer;
  Duration? _remaining;
  SleepTimerMode _mode = SleepTimerMode.inactive;
  String? _errorMessage;

  SleepTimerMode get mode => _mode;
  Duration? get remaining => _remaining;
  String? get errorMessage => _errorMessage;
  bool get isActive => _mode != SleepTimerMode.inactive;

  bool start(Duration duration) {
    if (playerController.currentSong == null) {
      _errorMessage = 'Start a song before setting a sleep timer.';
      notifyListeners();
      return false;
    }
    _timer?.cancel();
    _mode = SleepTimerMode.duration;
    _remaining = duration;
    _errorMessage = null;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _remaining ?? Duration.zero;
      if (current <= const Duration(seconds: 1)) {
        unawaited(playerController.stop());
        cancel();
        return;
      }
      _remaining = current - const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  bool startAtEndOfSong() {
    if (playerController.currentSong == null) {
      _errorMessage = 'Start a song before setting a sleep timer.';
      notifyListeners();
      return false;
    }
    _timer?.cancel();
    _timer = null;
    _mode = SleepTimerMode.endOfSong;
    _remaining = null;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  void handleSongCompleted() {
    if (_mode != SleepTimerMode.endOfSong) return;
    unawaited(playerController.stop());
    cancel();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _mode = SleepTimerMode.inactive;
    _remaining = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
