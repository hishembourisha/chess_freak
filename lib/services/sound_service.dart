// lib/services/sound_service.dart - Complete fixed version with your file structure
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
      
      if (kDebugMode) print('🔊 Chess sound service initialized');
      
      // Start background music immediately if enabled
      if (_musicEnabled) {
        await startBackgroundMusic();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize chess sound service: $e');
    }
  }

  /// Load sound settings from SharedPreferences
  static Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_effects_enabled') ?? true;
      _musicEnabled = prefs.getBool('background_music_enabled') ?? true;
      if (kDebugMode) print('🔊 Loaded chess settings - Sound Effects: $_soundEnabled, Background Music: $_musicEnabled');
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
      
      if (kDebugMode) print('🔊 Chess sound effects ${enabled ? 'enabled' : 'disabled'}');
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
      
      if (kDebugMode) print('🎵 Chess background music ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save background music setting: $e');
    }
  }

  /// Start background music (only depends on music setting, not sound effects)
  static Future<void> startBackgroundMusic() async {
    if (!_musicEnabled || !_isInitialized || _musicPlayer == null) {
      if (kDebugMode) print('🎵 Chess background music not started: music=$_musicEnabled, initialized=$_isInitialized');
      return;
    }

    if (_isMusicPlaying) {
      if (kDebugMode) print('🎵 Chess background music already playing');
      return;
    }

    try {
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.setVolume(0.3);
      
      // FIXED: Try multiple background music files with fallback
      bool musicStarted = false;
      
      // Primary background music file
      try {
        await _musicPlayer!.play(AssetSource('sounds/chess_background_music.mp3'));
        musicStarted = true;
        if (kDebugMode) print('🎵 Chess background music started (primary file)');
      } catch (e) {
        if (kDebugMode) print('⚠️ Primary background music file not found: $e');
      }
      
      // Fallback 1: Use a generic background music
      if (!musicStarted) {
        try {
          await _musicPlayer!.play(AssetSource('sounds/chess_background_music.mp3'));
          musicStarted = true;
          if (kDebugMode) print('🎵 Chess background music started (fallback 1)');
        } catch (e) {
          if (kDebugMode) print('⚠️ Fallback background music 1 not found: $e');
        }
      }
      
      // Fallback 2: Use a button sound on loop (very basic fallback)
      if (!musicStarted) {
        try {
          await _musicPlayer!.play(AssetSource('sounds/chess_button.mp3'));
          musicStarted = true;
          if (kDebugMode) print('🎵 Chess background music started (fallback 2 - button loop)');
        } catch (e) {
          if (kDebugMode) print('⚠️ Even button sound not found: $e');
        }
      }
      
      if (musicStarted) {
        _isMusicPlaying = true;
      } else {
        if (kDebugMode) print('❌ No background music files available');
        _isMusicPlaying = false;
      }
      
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to start chess background music: $e');
      _isMusicPlaying = false;
    }
  }

  /// Stop background music
  static Future<void> stopBackgroundMusic() async {
    if (_musicPlayer == null) return;
    
    try {
      await _musicPlayer!.stop();
      _isMusicPlaying = false;
      if (kDebugMode) print('🎵 Chess background music stopped');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to stop chess background music: $e');
    }
  }

  /// Pause background music (for app lifecycle events)
  static Future<void> pauseBackgroundMusic() async {
    if (_musicPlayer == null || !_isMusicPlaying) return;
    
    try {
      await _musicPlayer!.pause();
      if (kDebugMode) print('🎵 Chess background music paused');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to pause chess background music: $e');
    }
  }

  /// Resume background music (for app lifecycle events)
  static Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || _musicPlayer == null) {
      if (kDebugMode) print('🎵 Chess background music not resumed: music=$_musicEnabled, player=${_musicPlayer != null}');
      return;
    }
    
    try {
      await _musicPlayer!.resume();
      if (kDebugMode) print('🎵 Chess background music resumed');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to resume chess background music: $e');
      // If resume fails, try starting fresh
      await startBackgroundMusic();
    }
  }

  /// Play a sound effect (only depends on sound effects setting)
  static Future<void> playSound(ChessSoundEffect effect) async {
    if (!_soundEnabled || !_isInitialized || _effectsPlayer == null) return;

    try {
      await _effectsPlayer!.play(AssetSource(effect.filename));
      if (kDebugMode) print('🔊 Playing chess sound: ${effect.filename}');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to play chess sound ${effect.filename}: $e');
      // FIXED: Try fallback sound if specific sound fails
      if (effect != ChessSoundEffect.button) {
        try {
          await _effectsPlayer!.play(AssetSource('sounds/chess_button.mp3'));
          if (kDebugMode) print('🔊 Playing fallback button sound');
        } catch (fallbackError) {
          if (kDebugMode) print('❌ Even fallback sound failed: $fallbackError');
        }
      }
    }
  }

  // CHESS-SPECIFIC SOUND METHODS

  /// Play piece move sound (normal move)
  static Future<void> playMove() async {
    await playSound(ChessSoundEffect.move);
  }

  /// Play piece capture sound
  static Future<void> playCapture() async {
    await playSound(ChessSoundEffect.capture);
  }

  /// Play check sound
  static Future<void> playCheck() async {
    await playSound(ChessSoundEffect.check);
  }

  /// Play checkmate sound
  static Future<void> playCheckmate() async {
    await playSound(ChessSoundEffect.checkmate);
  }

  /// Play castling sound
  static Future<void> playCastling() async {
    await playSound(ChessSoundEffect.castling);
  }

  /// Play invalid move sound
  static Future<void> playInvalidMove() async {
    await playSound(ChessSoundEffect.invalidMove);
  }

  /// Play game start sound
  static Future<void> playGameStart() async {
    await playSound(ChessSoundEffect.gameStart);
  }

  /// Play game end sound (draw/stalemate)
  static Future<void> playGameEnd() async {
    await playSound(ChessSoundEffect.gameEnd);
  }

  /// Play button press sound (UI interactions)
  static Future<void> playButton() async {
    await playSound(ChessSoundEffect.button);
  }

  /// Play piece selection sound
  static Future<void> playSelect() async {
    await playSound(ChessSoundEffect.select);
  }

  /// Dispose the audio players
  static void dispose() {
    _effectsPlayer?.dispose();
    _musicPlayer?.dispose();
    _effectsPlayer = null;
    _musicPlayer = null;
    _isInitialized = false;
    _isMusicPlaying = false;
    if (kDebugMode) print('🔊 Chess sound service disposed');
  }

  /// Debug method to check current state
  static void debugSoundState() {
    if (kDebugMode) {
      print('=== 🔊 Chess Sound Service Debug ===');
      print('Sound Effects Enabled: $_soundEnabled');
      print('Background Music Enabled: $_musicEnabled');
      print('Initialized: $_isInitialized');
      print('Music Playing: $_isMusicPlaying');
      print('===================================');
    }
  }
}

/// Chess-specific sound effect definitions - FIXED to match your files
enum ChessSoundEffect {
  move('sounds/chess_move.mp3'),
  capture('sounds/chess_capture.mp3'),
  check('sounds/chess_check.mp3'),
  checkmate('sounds/chess_checkmate.wav'),  // This one is WAV
  castling('sounds/chess_castling.mp3'),
  invalidMove('sounds/chess_invalid.mp3'),
  gameStart('sounds/chess_start.mp3'),
  gameEnd('sounds/chess_end.mp3'),
  button('sounds/chess_button.mp3'),
  select('sounds/chess_select.mp3');

  const ChessSoundEffect(this.filename);
  final String filename;
}