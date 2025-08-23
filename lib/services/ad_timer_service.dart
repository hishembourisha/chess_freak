// lib/services/ad_timer_service.dart - Enhanced with progressive intervals
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ads_service.dart';
import '../helpers/ad_helper.dart';

class AdTimerService {
  // Keep your existing core structure
  static Timer? _adTimer;
  static DateTime? _lastAdShown;
  static DateTime? _timerStarted;
  
  // Add progressive features
  static int _adsShownThisSession = 0;
  static DateTime? _sessionStartTime;
  
  // Testing vs Production intervals
  static const int _testAdIntervalMinutes = 1; // For testing
  static const bool _useProgressiveIntervals = true; // Set to true for production
  
  // Progressive intervals: 5min, 7min, 10min, then 10min
  static int get _currentAdInterval {
    if (!_useProgressiveIntervals) {
      return _testAdIntervalMinutes; // Use 1 min for testing
    }
    
    if (_adsShownThisSession == 0) return 5;
    if (_adsShownThisSession == 1) return 7;
    return 10; // Cap at 10 minutes
  }
  
  /// Start the ad timer for free users
  static void startAdTimer() {
    // Don't start timer if user has Remove Ads
    if (!AdHelper.shouldShowAds()) {
      if (kDebugMode) print('🚫 Ad timer not started - user has Remove Ads');
      return;
    }
    
    // Prevent multiple timers
    if (_adTimer != null && _adTimer!.isActive) {
      if (kDebugMode) print('⚠️ Ad timer already running, not starting new one');
      return;
    }
    
    // Initialize session tracking
    _sessionStartTime ??= DateTime.now();
    
    // Stop existing timer if running
    _adTimer?.cancel();
    
    // Record when timer started
    _timerStarted = DateTime.now();
    
    // Start periodic timer with current interval
    _adTimer = Timer.periodic(Duration(minutes: _currentAdInterval), (timer) {
      if (kDebugMode) print('⏰ Ad timer triggered (${_currentAdInterval}min elapsed)');
      _showTimedAd();
    });
    
    if (kDebugMode) {
      print('▶️ Ad timer started for free user');
      print('🕐 Next ad in $_currentAdInterval minutes');
      print('📅 Timer started at: ${_timerStarted!.toLocal()}');
      if (_useProgressiveIntervals) {
        print('📊 Progressive mode: Session ads: $_adsShownThisSession');
      }
    }
  }
  
  /// Show a timed ad (called by timer)
  static void _showTimedAd() async {
    if (kDebugMode) print('🎯 === TIMED AD ATTEMPT ===');
    
    // Double-check ads should be shown
    if (!AdHelper.shouldShowAds()) {
      if (kDebugMode) print('🚫 Stopping ad timer - user now has Remove Ads');
      stopAdTimer();
      return;
    }
    
    // Check if we just showed an ad recently (safety check)
    if (_lastAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAdShown!);
      final minInterval = _useProgressiveIntervals ? 3 : _currentAdInterval;
      if (timeSinceLastAd.inMinutes < minInterval) {
        if (kDebugMode) {
          print('⏭️ Skipping ad - too recent (${timeSinceLastAd.inMinutes}min ago)');
        }
        return;
      }
    }
    
    if (kDebugMode) {
      print('🚀 Attempting to show interstitial ad...');
      print('📊 AdsService ready: ${AdsService.isInterstitialReady}');
    }
    
    try {
      // Try to show the interstitial ad
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      _adsShownThisSession++;
      
      if (kDebugMode) {
        print('✅ Timed interstitial ad shown successfully');
        print('📅 Ad shown at: ${_lastAdShown!.toLocal()}');
        print('📊 Ads this session: $_adsShownThisSession');
      }
      
      // Restart timer with new interval if using progressive mode
      if (_useProgressiveIntervals) {
        _restartTimerWithNewInterval();
      } else {
        if (kDebugMode) print('⏭️ Next ad in $_currentAdInterval minutes');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to show timed ad: $e');
        print('🔄 Will retry at next timer interval');
      }
    }
    
    if (kDebugMode) print('🎯 === TIMED AD ATTEMPT END ===');
  }
  
  /// Restart timer with new interval (for progressive mode)
  static void _restartTimerWithNewInterval() {
    if (!_useProgressiveIntervals) return;
    
    _adTimer?.cancel();
    _timerStarted = DateTime.now();
    
    _adTimer = Timer.periodic(Duration(minutes: _currentAdInterval), (timer) {
      if (kDebugMode) print('⏰ Ad timer triggered (${_currentAdInterval}min elapsed)');
      _showTimedAd();
    });
    
    if (kDebugMode) {
      print('🔄 Timer restarted with ${_currentAdInterval}min interval');
      print('⏭️ Next ad in $_currentAdInterval minutes');
    }
  }
  
  /// Stop the ad timer
  static void stopAdTimer() {
    if (_adTimer != null) {
      _adTimer!.cancel();
      _adTimer = null;
      _timerStarted = null;
      
      if (kDebugMode) print('⏹️ Ad timer stopped');
    }
  }
  
  /// Pause the ad timer (when app goes to background)
  static void pauseAdTimer() {
    if (!AdHelper.shouldShowAds()) {
      return; // No timer to pause for paid users
    }
    
    if (_adTimer != null && _lastAdShown == null) {
      // Reset timer when user pauses/resumes to prevent immediate ads
      _lastAdShown = DateTime.now();
      if (kDebugMode) print('⏸️ Ad timer paused - reset last ad time');
    }
  }
  
  /// Show ad between chess games (immediate)
  static void showGameTransitionAd() async {
    if (!AdHelper.shouldShowAds()) {
      if (kDebugMode) print('🚫 Game transition ad skipped - user has Remove Ads');
      return;
    }
    
    // Don't show transition ad if we just showed one recently
    if (_lastAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAdShown!);
      if (timeSinceLastAd.inMinutes < 2) { // Minimum 2 minutes between ads
        if (kDebugMode) {
          print('⏭️ Game transition ad skipped - too recent (${timeSinceLastAd.inMinutes}min ago)');
        }
        return;
      }
    }
    
    if (kDebugMode) print('🎮 Attempting to show game transition ad...');
    
    try {
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      _adsShownThisSession++;
      
      if (kDebugMode) {
        print('✅ Game transition ad shown successfully');
        print('📅 Ad shown at: ${_lastAdShown!.toLocal()}');
        print('📊 Ads this session: $_adsShownThisSession');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show game transition ad: $e');
    }
  }

  /// Show ad when chess game finishes (checkmate/stalemate/draw)
  static void showGameFinishAd() async {
    if (!AdHelper.shouldShowAds()) {
      if (kDebugMode) print('🚫 Game finish ad skipped - user has Remove Ads');
      return;
    }
    
    // Don't show finish ad if we just showed one recently (minimum 1 minute)
    if (_lastAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAdShown!);
      if (timeSinceLastAd.inMinutes < 1) {
        if (kDebugMode) {
          print('⏭️ Game finish ad skipped - too recent (${timeSinceLastAd.inMinutes}min ago)');
        }
        return;
      }
    }
    
    if (kDebugMode) print('🏁 Attempting to show game finish ad...');
    
    try {
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      _adsShownThisSession++;
      
      if (kDebugMode) {
        print('✅ Game finish ad shown successfully');
        print('📅 Ad shown at: ${_lastAdShown!.toLocal()}');
        print('📊 Ads this session: $_adsShownThisSession');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show game finish ad: $e');
    }
  }
  
  /// Force show an ad (for testing)
  static void forceShowAd() async {
    if (!kDebugMode) return; // Only in debug mode
    
    if (!AdHelper.shouldShowAds()) {
      print('🚫 Force ad skipped - user has Remove Ads');
      return;
    }
    
    print('🧪 FORCE SHOWING AD (DEBUG)');
    try {
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      _adsShownThisSession++;
      print('✅ Force ad shown successfully');
      print('📊 Ads this session: $_adsShownThisSession');
    } catch (e) {
      print('❌ Force ad failed: $e');
    }
  }
  
  /// Check if timer is currently active
  static bool get isTimerActive {
    return _adTimer != null && _adTimer!.isActive;
  }
  
  /// Get time until next ad (for debugging)
  static Duration? get timeUntilNextAd {
    if (!isTimerActive || _timerStarted == null) return null;
    
    final elapsed = DateTime.now().difference(_timerStarted!);
    final nextAdIn = Duration(minutes: _currentAdInterval) - elapsed;
    
    return nextAdIn.isNegative ? Duration.zero : nextAdIn;
  }
  
  /// Get time since last ad was shown
  static Duration? get timeSinceLastAd {
    if (_lastAdShown == null) return null;
    return DateTime.now().difference(_lastAdShown!);
  }
  
  /// Debug method to check timer status
  static void debugTimerStatus() {
    if (!kDebugMode) return;
    
    print('=== ⏰ Chess Ad Timer Debug ===');
    print('Should Show Ads: ${AdHelper.shouldShowAds()}');
    print('Timer Active: $isTimerActive');
    print('Current Interval: $_currentAdInterval minutes');
    print('Progressive Mode: $_useProgressiveIntervals');
    print('Session Ads: $_adsShownThisSession');
    print('Timer Started: ${_timerStarted?.toLocal() ?? 'Never'}');
    print('Session Started: ${_sessionStartTime?.toLocal() ?? 'Never'}');
    print('Last Ad Shown: ${_lastAdShown?.toLocal() ?? 'Never'}');
    
    if (timeSinceLastAd != null) {
      final since = timeSinceLastAd!;
      print('Time Since Last Ad: ${since.inMinutes}min ${since.inSeconds % 60}sec');
    }
    
    if (timeUntilNextAd != null) {
      final until = timeUntilNextAd!;
      print('Time Until Next Ad: ${until.inMinutes}min ${until.inSeconds % 60}sec');
    }
    
    print('AdsService Ready: ${AdsService.isInterstitialReady}');
    print('===============================');
  }
  
  /// Reset session for testing
  static void debugResetSession() {
    if (!kDebugMode) return;
    
    _adsShownThisSession = 0;
    _sessionStartTime = DateTime.now();
    _lastAdShown = null;
    print('🔄 DEBUG: Session reset');
  }
  
  /// Manual trigger for testing (debug only)
  static void debugTriggerAd() {
    if (!kDebugMode) return;
    
    print('🧪 DEBUG: Manually triggering ad timer...');
    _showTimedAd();
  }

  /// Manual trigger for testing game finish ad (debug only)
  static void debugTriggerGameFinishAd() {
    if (!kDebugMode) return;
    
    print('🧪 DEBUG: Manually triggering game finish ad...');
    showGameFinishAd();
  }

  /// Manual trigger for testing game transition ad (debug only)
  static void debugTriggerGameTransitionAd() {
    if (!kDebugMode) return;
    
    print('🧪 DEBUG: Manually triggering game transition ad...');
    showGameTransitionAd();
  }
  
  /// Toggle progressive mode for testing
  static void debugToggleProgressiveMode() {
    if (!kDebugMode) return;
    
    // Note: This would need to be a non-const variable to toggle
    print('🧪 Progressive mode is currently: $_useProgressiveIntervals');
    print('💡 To enable, set _useProgressiveIntervals = true in code');
  }
}