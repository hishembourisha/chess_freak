// lib/services/game_timer_service.dart
import 'dart:async';

class GameTimerService {
  static Timer? _timer;
  static int _seconds = 0;
  static bool _isRunning = false;
  static Function(int)? _onTimeUpdate;

  // Start the timer
  static void start({Function(int)? onTimeUpdate}) {
    if (_isRunning) return;
    
    _onTimeUpdate = onTimeUpdate;
    _isRunning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      _onTimeUpdate?.call(_seconds);
    });
    
    print('⏱️ Game timer started at ${formatTime(_seconds)}');
  }

  // Pause the timer (preserves current time)
  static void pause() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    
    print('⏸️ Game timer paused at ${formatTime(_seconds)}');
  }

  // Resume the timer (continues from where it was paused)
  static void resume({Function(int)? onTimeUpdate}) {
    if (_isRunning) return;
    
    _onTimeUpdate = onTimeUpdate ?? _onTimeUpdate;
    _isRunning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      _onTimeUpdate?.call(_seconds);
    });
    
    print('▶️ Game timer resumed from ${formatTime(_seconds)}');
  }

  // Stop and reset the timer completely
  static void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _seconds = 0;
    
    print('🛑 Game timer stopped and reset');
  }

  // Reset timer to specific time (for loading saved games)
  static void setTime(int seconds) {
    _seconds = seconds;
    _onTimeUpdate?.call(_seconds);
    print('🔄 Game timer set to ${formatTime(_seconds)}');
  }

  // Get current time in seconds
  static int getCurrentTime() => _seconds;

  // Check if timer is running
  static bool get isRunning => _isRunning;

  // Format time as MM:SS or HH:MM:SS
  static String formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}