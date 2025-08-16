// lib/services/ads_service.dart - Chess-optimized ad service
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../helpers/ad_helper.dart'; // CORRECT: AdHelper is in helpers folder
import 'dart:io';
import 'dart:async';

class AdsService {
  // Removed: Static _bannerAd field is no longer needed here.
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static bool _isInitialized = false;
  static final bool _debugMode = kDebugMode;

  // Load Ad Unit IDs from environment variables with better fallbacks
  static String get _bannerAdUnitId {
    String? envId;
    if (Platform.isAndroid) {
      envId = dotenv.env['ANDROID_BANNER_AD_UNIT_ID'];
      if (_debugMode) print('🔍 Android Banner ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/6300978111'; // Test ID
    } else if (Platform.isIOS) {
      envId = dotenv.env['IOS_BANNER_AD_UNIT_ID'];
      if (_debugMode) print('🔍 iOS Banner ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/2934735716'; // Test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get _interstitialAdUnitId {
    String? envId;
    if (Platform.isAndroid) {
      envId = dotenv.env['ANDROID_INTERSTITIAL_AD_UNIT_ID'];
      if (_debugMode) print('🔍 Android Interstitial ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/1033173712'; // Test ID
    } else if (Platform.isIOS) {
      envId = dotenv.env['IOS_INTERSTITIAL_AD_UNIT_ID'];
      if (_debugMode) print('🔍 iOS Interstitial ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/4411468910'; // Test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ADDED: New method to create a banner ad instance for the widget
  static Future<BannerAd?> createNewBannerAd() async {
    if (!AdHelper.canShowBannerAd()) {
      if (_debugMode) print('🚫 Banner ad creation skipped - user has Remove Ads');
      return null;
    }
    
    if (!_isInitialized) {
      if (_debugMode) print('⚠️ AdMob not initialized, initializing now...');
      await initialize();
    }
    
    if (_debugMode) print('📱 Creating a new banner ad instance...');
    
    final Completer<BannerAd?> completer = Completer();
    
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_debugMode) print('✅ Chess banner ad loaded successfully');
          completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          if (_debugMode) print('❌ Chess banner ad failed to load: $error');
          ad.dispose();
          completer.complete(null);
        },
        onAdOpened: (ad) {
          if (_debugMode) print('👆 Chess banner ad opened');
        },
        onAdClosed: (ad) {
          if (_debugMode) print('👋 Chess banner ad closed');
        },
        onAdClicked: (ad) {
          if (_debugMode) print('🖱️ Chess banner ad clicked');
        },
      ),
    );
    
    try {
      await ad.load();
    } catch (e) {
      if (_debugMode) print('❌ Banner ad load error: $e');
      ad.dispose();
      return null;
    }
    
    return completer.future;
  }
  
  // REMOVED: showBannerAd() method is no longer needed
  // ... (showBannerAd method was here) ...
  
  static Future<void> initialize() async {
    if (_isInitialized) {
      if (_debugMode) print('🔄 AdMob already initialized');
      return;
    }
    
    if (_debugMode) print('🚀 Initializing AdMob for Chess Freak...');
    
    try {
      // Initialize Mobile Ads SDK
      await MobileAds.instance.initialize();
      if (_debugMode) print('✅ Mobile Ads SDK initialized');
      
      // Set request configuration
      final RequestConfiguration requestConfiguration = RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        testDeviceIds: _debugMode ? ['YOUR_TEST_DEVICE_ID'] : null, // Add your test device ID
      );
      MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      
      _isInitialized = true;
      if (_debugMode) print('✅ AdMob configuration complete');
      
      // FIXED: Only pre-load ads for free users
      if (AdHelper.shouldShowAds()) {
        await _loadInterstitialAd();
      } else {
        if (_debugMode) print('🚫 Skipping ad pre-loading - user has Remove Ads');
      }
      
      // Debug configuration
      if (_debugMode) debugAdConfiguration();
      
    } catch (e) {
      if (_debugMode) print('❌ AdMob initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _loadInterstitialAd() async {
    // FIXED: Use AdHelper
    if (!AdHelper.canShowInterstitialAd()) {
      if (_debugMode) print('🚫 Interstitial ad skipped - user has Remove Ads');
      return;
    }
    
    if (_debugMode) print('📺 Loading interstitial ad for chess...');
    
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialAd!.setImmersiveMode(true);
            if (_debugMode) print('✅ Chess interstitial ad loaded successfully');
          },
          onAdFailedToLoad: (error) {
            if (_debugMode) print('❌ Chess interstitial ad failed to load: $error');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      if (_debugMode) print('❌ Interstitial ad load error: $e');
      _interstitialAd = null;
    }
  }

  static Future<void> showInterstitialAd() async {
    // FIXED: Use AdHelper
    if (!AdHelper.canShowInterstitialAd()) {
      if (_debugMode) print('🚫 Interstitial ad skipped - user has Remove Ads');
      return;
    }
    
    if (_interstitialAd == null) {
      if (_debugMode) print('⚠️ Interstitial ad not ready, loading new one');
      await _loadInterstitialAd();
      return;
    }

    if (_debugMode) print('📺 Showing chess interstitial ad...');

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (_debugMode) print('✅ Chess interstitial ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        if (_debugMode) print('👋 Chess interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        // FIXED: Only reload if ads should still be shown
        if (AdHelper.canShowInterstitialAd()) {
          _loadInterstitialAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (_debugMode) print('❌ Chess interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        if (AdHelper.canShowInterstitialAd()) {
          _loadInterstitialAd();
        }
      },
      onAdImpression: (ad) {
        if (_debugMode) print('👁️ Chess interstitial ad impression recorded');
      },
    );

    try {
      await _interstitialAd!.show();
    } catch (e) {
      if (_debugMode) print('❌ Interstitial ad show error: $e');
    }
  }

  /// Debug method to check AdMob configuration
  static void debugAdConfiguration() {
    print('=== 🔍 Chess Freak AdMob Debug ===');
    print('Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
    print('Is Initialized: $_isInitialized');
    print('Debug Mode: $_debugMode');
    
    // Check environment variables
    print('\n📋 Environment Variables:');
    if (Platform.isAndroid) {
      print('ANDROID_BANNER_AD_UNIT_ID: ${dotenv.env['ANDROID_BANNER_AD_UNIT_ID'] ?? 'NOT SET'}');
      print('ANDROID_INTERSTITIAL_AD_UNIT_ID: ${dotenv.env['ANDROID_INTERSTITIAL_AD_UNIT_ID'] ?? 'NOT SET'}');
    }
    
    // Check actual ad unit IDs being used
    print('\n🆔 Ad Unit IDs in Use:');
    try {
      print('Banner: $_bannerAdUnitId');
      print('Interstitial: $_interstitialAdUnitId');
    } catch (e) {
      print('Error getting ad unit IDs: $e');
    }
    
    // Check ad states
    print('\n📊 Chess Ad States:');
    // Removed: Banner ad loaded state check is no longer needed in service
    print('Interstitial Ready: $isInterstitialReady');
    
    // FIXED: Use AdHelper for debugging
    print('Should Show Ads: ${AdHelper.shouldShowAds()}');
    print('Can Show Banner: ${AdHelper.canShowBannerAd()}');
    print('Can Show Interstitial: ${AdHelper.canShowInterstitialAd()}');
    
    print('==================================\n');
  }

  /// Check if ads are ready to show - FIXED: Also check if ads should be shown
  static bool get isInterstitialReady => _interstitialAd != null && AdHelper.canShowInterstitialAd();
  // Removed: isBannerLoaded getter
  // static bool get isBannerLoaded => _bannerAd != null && AdHelper.canShowBannerAd();

  // Removed: Get banner ad widget for displaying in UI
  // static BannerAd? get bannerAd => AdHelper.canShowBannerAd() ? _bannerAd : null;

  /// Force reload ads (useful after network connectivity issues)
  static Future<void> reloadAds() async {
    if (_debugMode) print('🔄 Reloading chess ads...');
    
    // FIXED: Only reload if ads should be shown
    if (AdHelper.canShowInterstitialAd()) {
      await _loadInterstitialAd();
    }
  }

  /// Dispose all ads
  static void dispose() {
    if (_debugMode) print('🗑️ Disposing all chess ads...');
    // Removed: Banner ad dispose logic is now handled by the widget
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}