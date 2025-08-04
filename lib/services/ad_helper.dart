// lib/services/ad_helper.dart - Fixed version with robust state management
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdHelper class for managing ad display logic throughout the app
/// This class uses SharedPreferences as the single source of truth for ad status
class AdHelper {
  static bool _adsRemoved = false;
  static bool _isInitialized = false;
  
  // Shared preference key - used by both AdHelper and IAPService
  static const String _adsRemovedKey = 'ads_removed';
  
  /// Initialize the ad helper and load purchase state
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load from SharedPreferences as the single source of truth
      final prefs = await SharedPreferences.getInstance();
      _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ AdHelper initialized - ads removed: $_adsRemoved');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdHelper initialization failed: $e');
      }
      _adsRemoved = false;
      _isInitialized = true;
    }
  }
  
  /// Update the ads removed status (called when purchase is made or status changes)
  static Future<void> updateAdsRemovedStatus(bool removed) async {
    _adsRemoved = removed;
    
    if (kDebugMode) {
      print('🔄 AdHelper: Ads removed status updated to $removed');
    }
    
    // Update SharedPreferences to ensure persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adsRemovedKey, removed);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save ads removed status: $e');
      }
    }
  }
  
  /// Check if ads should be shown anywhere in the app
  static bool shouldShowAds() {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('⚠️ AdHelper not initialized, assuming ads should show');
      }
      return true; // Default to showing ads if not initialized
    }
    
    return !_adsRemoved;
  }
  
  /// Check if interstitial ads can be shown
  static bool canShowInterstitialAd() {
    return shouldShowAds();
  }
  
  /// Check if banner ads can be shown
  static bool canShowBannerAd() {
    return shouldShowAds();
  }
  
  /// Check if rewarded ads can be shown
  static bool canShowRewardedAd() {
    return shouldShowAds();
  }
  
  /// Force refresh the ads status from SharedPreferences
  static Future<void> refreshStatus() async {
    try {
      // Reload from SharedPreferences (single source of truth)
      final prefs = await SharedPreferences.getInstance();
      bool currentStatus = prefs.getBool(_adsRemovedKey) ?? false;
      
      if (_adsRemoved != currentStatus) {
        _adsRemoved = currentStatus;
        if (kDebugMode) {
          print('🔄 AdHelper status refreshed: ads removed = $_adsRemoved');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to refresh ad status: $e');
      }
    }
  }
  
  /// Get current ads removed status without async call (for immediate checks)
  static bool get adsRemoved => _adsRemoved;
  
  /// Get the SharedPreferences key used for ads status (for other services to use)
  static String get adsRemovedKey => _adsRemovedKey;
  
  /// Debug method to log ad status
  static void debugAdStatus() {
    if (kDebugMode) {
      print('=== 📺 Ad Status Debug ===');
      print('Initialized: $_isInitialized');
      print('Internal Ads Removed: $_adsRemoved');
      print('Should Show Ads: ${shouldShowAds()}');
      print('Can Show Banner: ${canShowBannerAd()}');
      print('Can Show Interstitial: ${canShowInterstitialAd()}');
      print('Can Show Rewarded: ${canShowRewardedAd()}');
      print('========================');
    }
  }
}