// lib/services/vibration_service.dart - Chess-optimized vibration service
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class VibrationService {
  static bool _vibrationEnabled = true;
  static bool _isInitialized = false;

  /// Initialize the vibration service and load settings
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadVibrationSettings();
      _isInitialized = true;
      if (kDebugMode) print('📳 Chess vibration service initialized');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize chess vibration service: $e');
    }
  }

  /// Load vibration settings from SharedPreferences
  static Future<void> _loadVibrationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      if (kDebugMode) print('📳 Chess vibration enabled: $_vibrationEnabled');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load chess vibration settings: $e');
    }
  }

  /// Get current vibration enabled status
  static bool get isVibrationEnabled => _vibrationEnabled;

  /// Enable or disable vibration
  static Future<void> setVibrationEnabled(bool enabled) async {
    try {
      _vibrationEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vibration_enabled', enabled);
      if (kDebugMode) print('📳 Chess vibration ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save chess vibration setting: $e');
    }
  }

  /// Light vibration for subtle feedback
  static Future<void> light() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.lightImpact();
      if (kDebugMode) print('📳 Light chess vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger light vibration: $e');
    }
  }

  /// Medium vibration for moderate feedback
  static Future<void> medium() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.mediumImpact();
      if (kDebugMode) print('📳 Medium chess vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger medium vibration: $e');
    }
  }

  /// Heavy vibration for strong feedback
  static Future<void> heavy() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.heavyImpact();
      if (kDebugMode) print('📳 Heavy chess vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger heavy vibration: $e');
    }
  }

  /// Selection vibration for UI navigation
  static Future<void> selection() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.selectionClick();
      if (kDebugMode) print('📳 Chess selection vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger selection vibration: $e');
    }
  }

  // CHESS-SPECIFIC VIBRATION METHODS

  /// Vibration for piece selection
  static Future<void> pieceSelected() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await selection();
  }

  /// Vibration for normal piece move
  static Future<void> pieceMove() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Vibration for piece capture
  static Future<void> pieceCapture() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await medium();
  }

  /// Vibration for check
  static Future<void> check() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await heavy();
  }

  /// Vibration for checkmate (celebratory pattern)
  static Future<void> checkmate() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      // Create a checkmate celebration pattern
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      if (kDebugMode) print('📳 Chess checkmate celebration vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger checkmate vibration: $e');
    }
  }

  /// Vibration for castling move
  static Future<void> castling() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      // Special pattern for castling (two quick vibrations)
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      if (kDebugMode) print('📳 Chess castling vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger castling vibration: $e');
    }
  }

  /// Vibration for invalid move attempt
  static Future<void> invalidMove() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await heavy();
  }

  /// Vibration for game start
  static Future<void> gameStart() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await medium();
  }

  /// Vibration for game end (draw/stalemate)
  static Future<void> gameEnd() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      // Pattern for game end (different from checkmate)
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.lightImpact();
      if (kDebugMode) print('📳 Chess game end vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger game end vibration: $e');
    }
  }

  /// Vibration for AI move (opponent move)
  static Future<void> aiMove() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Vibration for button presses (UI interactions)
  static Future<void> buttonPressed() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Vibration for promotion (pawn reaching end)
  static Future<void> promotion() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      // Special pattern for pawn promotion
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      if (kDebugMode) print('📳 Chess promotion vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger promotion vibration: $e');
    }
  }

  /// Vibration for errors (general errors)
  static Future<void> errorEntry() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await heavy();
  }

  /// Test vibration (for settings)
  static Future<void> test() async {
    if (!_isInitialized) return;
    
    // Temporarily enable vibration for testing
    bool originalSetting = _vibrationEnabled;
    _vibrationEnabled = true;
    
    try {
      await medium();
      if (kDebugMode) print('📳 Chess test vibration triggered');
    } finally {
      _vibrationEnabled = originalSetting;
    }
  }
}