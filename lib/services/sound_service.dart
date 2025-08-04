// lib/services/sound_service.dart - Fixed with decoupled music control
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static AudioPlayer? _effectsPlayer;
  static AudioPlayer? _musicPlayer;
  static bool _soundEnabled = true; // Sound effects only
  static bool _musicEnabled = true; // Background music only (separate from sound)
  static bool _isInitialized = false;
  static bool _isMusicPlaying = false;

  /// Initialize the sound service and load settings
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _effectsPlayer = AudioPlayer();
      _musicPlayer = AudioPlayer();
      
      await _loadSettings();
      _isInitialized = true;
      
      if (kDebugMode) print('🔊 Sound service initialized');
      
      // Start background music immediately if enabled
      if (_musicEnabled) {
        await startBackgroundMusic();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize sound service: $e');
    }
  }

  /// Load sound settings from SharedPreferences
  static Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_effects_enabled') ?? true;
      _musicEnabled = prefs.getBool('background_music_enabled') ?? true;
      if (kDebugMode) print('🔊 Loaded settings - Sound Effects: $_soundEnabled, Background Music: $_musicEnabled');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load sound settings: $e');
      // Use defaults if loading fails
      _soundEnabled = true;
      _musicEnabled = true;
    }
  }

  /// Get current sound effects enabled status
  static bool get isSoundEnabled => _soundEnabled;
  
  /// Get current background music enabled status
  static bool get isMusicEnabled => _musicEnabled;
  
  /// Get current music playing status
  static bool get isMusicPlaying => _isMusicPlaying;

  /// Enable or disable sound effects ONLY (does not affect music)
  static Future<void> setSoundEnabled(bool enabled) async {
    try {
      _soundEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_effects_enabled', enabled);
      
      if (kDebugMode) print('🔊 Sound effects ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save sound effects setting: $e');
    }
  }

  /// Enable or disable background music ONLY (separate from sound effects)
  static Future<void> setMusicEnabled(bool enabled) async {
    try {
      _musicEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_music_enabled', enabled);
      
      // Control music playback based on music setting only
      if (enabled) {
        await startBackgroundMusic();
      } else {
        await stopBackgroundMusic();
      }
      
      if (kDebugMode) print('🎵 Background music ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save background music setting: $e');
    }
  }

  /// Start background music (only depends on music setting, not sound effects)
  static Future<void> startBackgroundMusic() async {
    if (!_musicEnabled || !_isInitialized || _musicPlayer == null) {
      if (kDebugMode) print('🎵 Background music not started: music=$_musicEnabled, initialized=$_isInitialized');
      return;
    }

    if (_isMusicPlaying) {
      if (kDebugMode) print('🎵 Background music already playing');
      return;
    }

    try {
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.setVolume(0.3);
      await _musicPlayer!.play(AssetSource('sounds/background_music.mp3'));
      _isMusicPlaying = true;
      if (kDebugMode) print('🎵 Background music started');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to start background music: $e');
      _isMusicPlaying = false;
    }
  }

  /// Stop background music
  static Future<void> stopBackgroundMusic() async {
    if (_musicPlayer == null) return;
    
    try {
      await _musicPlayer!.stop();
      _isMusicPlaying = false;
      if (kDebugMode) print('🎵 Background music stopped');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to stop background music: $e');
    }
  }

  /// Pause background music (for app lifecycle events)
  static Future<void> pauseBackgroundMusic() async {
    if (_musicPlayer == null || !_isMusicPlaying) return;
    
    try {
      await _musicPlayer!.pause();
      if (kDebugMode) print('🎵 Background music paused');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to pause background music: $e');
    }
  }

  /// Resume background music (for app lifecycle events)
  static Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || _musicPlayer == null) {
      if (kDebugMode) print('🎵 Background music not resumed: music=$_musicEnabled, player=${_musicPlayer != null}');
      return;
    }
    
    try {
      await _musicPlayer!.resume();
      if (kDebugMode) print('🎵 Background music resumed');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to resume background music: $e');
    }
  }

  /// Play a sound effect (only depends on sound effects setting)
  static Future<void> playSound(SoundEffect effect) async {
    if (!_soundEnabled || !_isInitialized || _effectsPlayer == null) return;

    try {
      await _effectsPlayer!.play(AssetSource(effect.filename));
      if (kDebugMode) print('🔊 Playing: ${effect.filename}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to play sound ${effect.filename}: $e');
    }
  }

  /// Play cell selection sound
  static Future<void> playSelect() async {
    await playSound(SoundEffect.select);
  }

  /// Play number entry sound
  static Future<void> playPlace() async {
    await playSound(SoundEffect.place);
  }

  /// Play error sound
  static Future<void> playError() async {
    await playSound(SoundEffect.error);
  }

  /// Play hint sound
  static Future<void> playHint() async {
    await playSound(SoundEffect.hint);
  }

  /// Play puzzle completion sound
  static Future<void> playComplete() async {
    await playSound(SoundEffect.complete);
  }

  /// Play button press sound
  static Future<void> playButton() async {
    await playSound(SoundEffect.button);
  }

  /// Play note mode toggle sound
  static Future<void> playToggle() async {
    await playSound(SoundEffect.toggle);
  }

  /// Dispose the audio players
  static void dispose() {
    _effectsPlayer?.dispose();
    _musicPlayer?.dispose();
    _effectsPlayer = null;
    _musicPlayer = null;
    _isInitialized = false;
    _isMusicPlaying = false;
    if (kDebugMode) print('🔊 Sound service disposed');
  }

  /// Debug method to check current state
  static void debugSoundState() {
    if (kDebugMode) {
      print('=== 🔊 Sound Service Debug ===');
      print('Sound Effects Enabled: $_soundEnabled');
      print('Background Music Enabled: $_musicEnabled');
      print('Initialized: $_isInitialized');
      print('Music Playing: $_isMusicPlaying');
      print('==============================');
    }
  }
}

/// Sound effect definitions
enum SoundEffect {
  select('sounds/select.mp3'),
  place('sounds/place.mp3'),
  error('sounds/error.mp3'),
  hint('sounds/hint.mp3'),
  complete('sounds/complete.mp3'),
  button('sounds/button.mp3'),
  toggle('sounds/toggle.mp3');

  const SoundEffect(this.filename);
  final String filename;
}