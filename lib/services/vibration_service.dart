// lib/services/vibration_service.dart
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
      if (kDebugMode) print('📳 Vibration service initialized');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize vibration service: $e');
    }
  }

  /// Load vibration settings from SharedPreferences
  static Future<void> _loadVibrationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      if (kDebugMode) print('📳 Vibration enabled: $_vibrationEnabled');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load vibration settings: $e');
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
      if (kDebugMode) print('📳 Vibration ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save vibration setting: $e');
    }
  }

  /// Light vibration for subtle feedback (cell selection, number entry)
  static Future<void> light() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.lightImpact();
      if (kDebugMode) print('📳 Light vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger light vibration: $e');
    }
  }

  /// Medium vibration for moderate feedback (hints, toggles)
  static Future<void> medium() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.mediumImpact();
      if (kDebugMode) print('📳 Medium vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger medium vibration: $e');
    }
  }

  /// Heavy vibration for strong feedback (errors, completion)
  static Future<void> heavy() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.heavyImpact();
      if (kDebugMode) print('📳 Heavy vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger heavy vibration: $e');
    }
  }

  /// Selection vibration for UI navigation
  static Future<void> selection() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      await HapticFeedback.selectionClick();
      if (kDebugMode) print('📳 Selection vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger selection vibration: $e');
    }
  }

  /// Custom vibration patterns for specific game events
  
  /// Vibration for correct number placement
  static Future<void> correctEntry() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Vibration for incorrect number placement (error)
  static Future<void> errorEntry() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await heavy();
  }

  /// Vibration for hint usage
  static Future<void> hintUsed() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await medium();
  }

  /// Vibration for puzzle completion (celebratory pattern)
  static Future<void> puzzleComplete() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    
    try {
      // Create a celebratory vibration pattern
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      if (kDebugMode) print('📳 Puzzle completion celebration vibration');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to trigger completion vibration: $e');
    }
  }

  /// Vibration for cell selection
  static Future<void> cellSelected() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await selection();
  }

  /// Vibration for button presses
  static Future<void> buttonPressed() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Vibration for mode toggles (note mode, etc.)
  static Future<void> modeToggle() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await medium();
  }

  /// Vibration for clearing cells
  static Future<void> cellCleared() async {
    if (!_vibrationEnabled || !_isInitialized) return;
    await light();
  }

  /// Test vibration (for settings)
  static Future<void> test() async {
    if (!_isInitialized) return;
    
    // Temporarily enable vibration for testing
    bool originalSetting = _vibrationEnabled;
    _vibrationEnabled = true;
    
    try {
      await medium();
      if (kDebugMode) print('📳 Test vibration triggered');
    } finally {
      _vibrationEnabled = originalSetting;
    }
  }
}