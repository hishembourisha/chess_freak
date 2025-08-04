// Enhanced ads_service.dart - Fixed for Remove Ads users
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ad_helper.dart'; // ADDED: Use AdHelper instead of manual checking
import 'dart:io';

class AdsService {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static bool _isInitialized = false;
  static bool _debugMode = kDebugMode;

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

  static String get _rewardedAdUnitId {
    String? envId;
    if (Platform.isAndroid) {
      envId = dotenv.env['ANDROID_REWARDED_AD_UNIT_ID'];
      if (_debugMode) print('🔍 Android Rewarded ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/5224354917'; // Test ID
    } else if (Platform.isIOS) {
      envId = dotenv.env['IOS_REWARDED_AD_UNIT_ID'];
      if (_debugMode) print('🔍 iOS Rewarded ID from env: $envId');
      return envId ?? 'ca-app-pub-3940256099942544/1712485313'; // Test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  static Future<void> initialize() async {
    if (_isInitialized) {
      if (_debugMode) print('🔄 AdMob already initialized');
      return;
    }
    
    if (_debugMode) print('🚀 Initializing AdMob...');
    
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
        await _loadRewardedAd();
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

  static Future<void> showBannerAd() async {
    // FIXED: Use AdHelper instead of manual check
    if (!AdHelper.canShowBannerAd()) {
      if (_debugMode) print('🚫 Banner ad skipped - user has Remove Ads');
      return;
    }
    
    if (!_isInitialized) {
      if (_debugMode) print('⚠️ AdMob not initialized, initializing now...');
      await initialize();
    }
    
    // Dispose existing banner
    _bannerAd?.dispose();
    
    if (_debugMode) print('📱 Loading banner ad...');
    
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_debugMode) print('✅ Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          if (_debugMode) print('❌ Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
        },
        onAdOpened: (ad) {
          if (_debugMode) print('👆 Banner ad opened');
        },
        onAdClosed: (ad) {
          if (_debugMode) print('👋 Banner ad closed');
        },
        onAdClicked: (ad) {
          if (_debugMode) print('🖱️ Banner ad clicked');
        },
      ),
    );
    
    try {
      await _bannerAd!.load();
    } catch (e) {
      if (_debugMode) print('❌ Banner ad load error: $e');
      _bannerAd?.dispose();
      _bannerAd = null;
    }
  }

  static Future<void> _loadInterstitialAd() async {
    // FIXED: Use AdHelper
    if (!AdHelper.canShowInterstitialAd()) {
      if (_debugMode) print('🚫 Interstitial ad skipped - user has Remove Ads');
      return;
    }
    
    if (_debugMode) print('📺 Loading interstitial ad...');
    
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialAd!.setImmersiveMode(true);
            if (_debugMode) print('✅ Interstitial ad loaded successfully');
          },
          onAdFailedToLoad: (error) {
            if (_debugMode) print('❌ Interstitial ad failed to load: $error');
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

    if (_debugMode) print('📺 Showing interstitial ad...');

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (_debugMode) print('✅ Interstitial ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        if (_debugMode) print('👋 Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        // FIXED: Only reload if ads should still be shown
        if (AdHelper.canShowInterstitialAd()) {
          _loadInterstitialAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (_debugMode) print('❌ Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        if (AdHelper.canShowInterstitialAd()) {
          _loadInterstitialAd();
        }
      },
      onAdImpression: (ad) {
        if (_debugMode) print('👁️ Interstitial ad impression recorded');
      },
    );

    try {
      await _interstitialAd!.show();
    } catch (e) {
      if (_debugMode) print('❌ Interstitial ad show error: $e');
    }
  }

  static Future<void> _loadRewardedAd() async {
    // FIXED: Use AdHelper
    if (!AdHelper.canShowRewardedAd()) {
      if (_debugMode) print('🚫 Rewarded ad skipped - user has Remove Ads');
      return;
    }
    
    if (_debugMode) print('🎁 Loading rewarded ad...');
    
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            if (_debugMode) print('✅ Rewarded ad loaded successfully');
          },
          onAdFailedToLoad: (error) {
            if (_debugMode) print('❌ Rewarded ad failed to load: $error');
            _rewardedAd = null;
          },
        ),
      );
    } catch (e) {
      if (_debugMode) print('❌ Rewarded ad load error: $e');
      _rewardedAd = null;
    }
  }

  static Future<void> showRewardedAd({required VoidCallback onReward}) async {
    // FIXED: Use AdHelper and give reward to paid users automatically
    if (!AdHelper.canShowRewardedAd()) {
      if (_debugMode) print('🚫 Rewarded ad skipped - user has Remove Ads, giving reward automatically');
      onReward();
      return;
    }
    
    if (_rewardedAd == null) {
      if (_debugMode) print('⚠️ Rewarded ad not ready, trying to load');
      await _loadRewardedAd();
      throw Exception('Ad not ready. Please try again in a moment.');
    }

    if (_debugMode) print('🎁 Showing rewarded ad...');

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (_debugMode) print('✅ Rewarded ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        if (_debugMode) print('👋 Rewarded ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        // FIXED: Only reload if ads should still be shown
        if (AdHelper.canShowRewardedAd()) {
          _loadRewardedAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (_debugMode) print('❌ Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        if (AdHelper.canShowRewardedAd()) {
          _loadRewardedAd();
        }
        throw Exception('Failed to show ad: $error');
      },
      onAdImpression: (ad) {
        if (_debugMode) print('👁️ Rewarded ad impression recorded');
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          if (_debugMode) print('🎉 User earned reward: ${reward.amount} ${reward.type}');
          onReward();
        },
      );
    } catch (e) {
      if (_debugMode) print('❌ Rewarded ad show error: $e');
      throw Exception('Failed to show ad: $e');
    }
  }

  /// Debug method to check AdMob configuration
  static void debugAdConfiguration() {
    print('=== 🔍 AdMob Debug Information ===');
    print('Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
    print('Is Initialized: $_isInitialized');
    print('Debug Mode: $_debugMode');
    
    // Check environment variables
    print('\n📋 Environment Variables:');
    if (Platform.isAndroid) {
      print('ANDROID_BANNER_AD_UNIT_ID: ${dotenv.env['ANDROID_BANNER_AD_UNIT_ID'] ?? 'NOT SET'}');
      print('ANDROID_INTERSTITIAL_AD_UNIT_ID: ${dotenv.env['ANDROID_INTERSTITIAL_AD_UNIT_ID'] ?? 'NOT SET'}');
      print('ANDROID_REWARDED_AD_UNIT_ID: ${dotenv.env['ANDROID_REWARDED_AD_UNIT_ID'] ?? 'NOT SET'}');
    }
    
    // Check actual ad unit IDs being used
    print('\n🆔 Ad Unit IDs in Use:');
    try {
      print('Banner: $_bannerAdUnitId');
      print('Interstitial: $_interstitialAdUnitId');
      print('Rewarded: $_rewardedAdUnitId');
    } catch (e) {
      print('Error getting ad unit IDs: $e');
    }
    
    // Check ad states
    print('\n📊 Ad States:');
    print('Banner Ad Loaded: $isBannerLoaded');
    print('Interstitial Ready: $isInterstitialReady');
    print('Rewarded Ready: $isRewardedReady');
    
    // FIXED: Use AdHelper for debugging
    print('Should Show Ads: ${AdHelper.shouldShowAds()}');
    print('Can Show Banner: ${AdHelper.canShowBannerAd()}');
    print('Can Show Interstitial: ${AdHelper.canShowInterstitialAd()}');
    print('Can Show Rewarded: ${AdHelper.canShowRewardedAd()}');
    
    print('================================\n');
  }

  /// Check if ads are ready to show - FIXED: Also check if ads should be shown
  static bool get isInterstitialReady => _interstitialAd != null && AdHelper.canShowInterstitialAd();
  static bool get isRewardedReady => _rewardedAd != null && AdHelper.canShowRewardedAd();
  static bool get isBannerLoaded => _bannerAd != null && AdHelper.canShowBannerAd();

  /// Get banner ad widget for displaying in UI
  static BannerAd? get bannerAd => AdHelper.canShowBannerAd() ? _bannerAd : null;

  /// Force reload ads (useful after network connectivity issues)
  static Future<void> reloadAds() async {
    if (_debugMode) print('🔄 Reloading all ads...');
    
    // FIXED: Only reload if ads should be shown
    if (AdHelper.canShowInterstitialAd()) {
      await _loadInterstitialAd();
    }
    if (AdHelper.canShowRewardedAd()) {
      await _loadRewardedAd();
    }
  }

  /// Dispose all ads
  static void dispose() {
    if (_debugMode) print('🗑️ Disposing all ads...');
    _bannerAd?.dispose();
    _bannerAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}