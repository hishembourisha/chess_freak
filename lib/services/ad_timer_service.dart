// lib/services/ad_timer_service.dart - Chess-optimized ad timing
import 'dart:async';
import 'ads_service.dart';
import '../helpers/ad_helper.dart'; // CORRECT: AdHelper is in helpers folder

class AdTimerService {
  static Timer? _adTimer;
  static DateTime? _lastAdShown;
  static const int _adIntervalMinutes = 10; // CHANGED: 10 minutes for chess (longer sessions)
  
  // FIXED: Only start timer for free users
  static void startAdTimer() {
    // Don't start timer if user has Remove Ads
    if (!AdHelper.shouldShowAds()) {
      print('🚫 Ad timer not started - user has Remove Ads');
      return;
    }
    
    _adTimer?.cancel();
    _adTimer = Timer.periodic(Duration(minutes: _adIntervalMinutes), (timer) {
      _showTimedAd();
    });
    print('⏰ Ad timer started for free user (${_adIntervalMinutes}min intervals)');
  }
  
  static void _showTimedAd() async {
    // Double-check ads should be shown
    if (!AdHelper.shouldShowAds()) {
      print('🚫 Stopping ad timer - user now has Remove Ads');
      stopAdTimer();
      return;
    }
    
    // Don't show if we just showed an ad recently
    if (_lastAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAdShown!);
      if (timeSinceLastAd.inMinutes < _adIntervalMinutes) return;
    }
    
    try {
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      print('🎯 Timed interstitial ad shown (chess game)');
    } catch (e) {
      print('⚠️ Failed to show timed ad: $e');
    }
  }
  
  static void stopAdTimer() {
    _adTimer?.cancel();
    _adTimer = null;
    print('⏹️ Ad timer stopped');
  }
  
  // FIXED: Only pause for free users
  static void pauseAdTimer() {
    if (!AdHelper.shouldShowAds()) {
      return; // No timer to pause for paid users
    }
    
    // Reset timer when user pauses/resumes
    _lastAdShown = DateTime.now();
    print('⏸️ Ad timer paused');
  }
  
  // Method to show ad between chess games
  static void showGameTransitionAd() async {
    if (!AdHelper.shouldShowAds()) {
      print('🚫 Game transition ad skipped - user has Remove Ads');
      return;
    }
    
    try {
      await AdsService.showInterstitialAd();
      _lastAdShown = DateTime.now();
      print('🎯 Game transition ad shown');
    } catch (e) {
      print('⚠️ Failed to show game transition ad: $e');
    }
  }
  
  // ADDED: Method to check timer status
  static bool get isTimerActive {
    return _adTimer != null && _adTimer!.isActive;
  }
  
  // ADDED: Debug method
  static void debugTimerStatus() {
    print('=== ⏰ Chess Ad Timer Status ===');
    print('Should Show Ads: ${AdHelper.shouldShowAds()}');
    print('Timer Active: $isTimerActive');
    print('Interval: ${_adIntervalMinutes} minutes');
    print('Last Ad Shown: $_lastAdShown');
    print('===============================');
  }
}