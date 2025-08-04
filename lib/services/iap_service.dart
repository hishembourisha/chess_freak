// lib/services/iap_service.dart - Fixed version without circular dependency
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class IAPService {
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _isInitialized = false;
  static bool _isAdsRemoved = false;
  static bool _isAvailable = false;

  // Shared preference key - same as used by AdHelper
  static const String _adsRemovedKey = 'ads_removed';

  // Product IDs - these should match your Google Play Console / App Store Connect
  static const String removeAdsProductId = 'remove_ads_sudoku';
  static const String hintPack5ProductId = 'hint_pack_5';
  
  // Hint store product IDs (from your hint store)
  static const String hintPack200ProductId = 'hint_pack_200';
  static const String hintPack500ProductId = 'hint_pack_500';
  static const String hintPack1000ProductId = 'hint_pack_1000';
  static const String hintPackUnlimitedProductId = 'hint_pack_unlimited';
  
  static const Set<String> _productIds = {
    removeAdsProductId,
    hintPack5ProductId,
    hintPack200ProductId,
    hintPack500ProductId,
    hintPack1000ProductId,
    hintPackUnlimitedProductId,
  };

  // Map product IDs to hint amounts
  static const Map<String, int> _hintAmounts = {
    hintPack5ProductId: 5,
    hintPack200ProductId: 200,
    hintPack500ProductId: 500,
    hintPack1000ProductId: 1000,
    hintPackUnlimitedProductId: 2500,
  };

  // Getters
  static bool get isAdsRemoved => _isAdsRemoved;
  static bool get isAvailable => _isAvailable;
  static bool get isInitialized => _isInitialized;

  /// Initialize the IAP service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if in-app purchases are available
      _isAvailable = await _inAppPurchase.isAvailable();
      
      if (!_isAvailable) {
        if (kDebugMode) print('⚠️ In-app purchases not available on this device');
        // Still load from SharedPreferences even if IAP not available
        await _loadPurchases();
        _isInitialized = true;
        return;
      }

      if (kDebugMode) print('✅ IAP service available, initializing...');

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          if (kDebugMode) print('❌ Purchase stream error: $error');
        },
      );

      // Load previous purchases
      await _loadPurchases();
      _isInitialized = true;
      
      if (kDebugMode) print('✅ IAP service initialized successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize IAP: $e');
      // Still try to load from SharedPreferences
      await _loadPurchases();
      _isInitialized = true;
    }
  }

  /// Load purchases from local storage and restore from store
  static Future<void> _loadPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAdsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
      
      if (kDebugMode) print('📱 Loaded purchases: ads removed = $_isAdsRemoved');

      // Also restore purchases from store if available
      if (_isAvailable) {
        await _inAppPurchase.restorePurchases();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error loading purchases: $e');
    }
  }

  /// Handle purchase updates from the store
  static void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (kDebugMode) print('📦 Purchase update: ${purchaseDetails.productID} - ${purchaseDetails.status}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          if (kDebugMode) print('⏳ Purchase pending: ${purchaseDetails.productID}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          if (kDebugMode) print('❌ Purchase error: ${purchaseDetails.error}');
          break;
        case PurchaseStatus.canceled:
          if (kDebugMode) print('❌ Purchase canceled: ${purchaseDetails.productID}');
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchases and grants
  static Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productId = purchaseDetails.productID;
      
      if (productId == removeAdsProductId) {
        await prefs.setBool(_adsRemovedKey, true);
        _isAdsRemoved = true;
        
        if (kDebugMode) print('✅ Ads removed successfully - SharedPreferences updated');
        
      } else if (_hintAmounts.containsKey(productId)) {
        // Handle hint purchases
        int currentHints = prefs.getInt('hint_balance') ?? 0;
        int hintsToAdd = _hintAmounts[productId]!;
        await prefs.setInt('hint_balance', currentHints + hintsToAdd);
        if (kDebugMode) print('✅ $hintsToAdd hints added (total: ${currentHints + hintsToAdd})');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error handling purchase: $e');
    }
  }

  /// Get available products from the store
  static Future<List<ProductDetails>> getProducts() async {
    if (!_isInitialized || !_isAvailable) {
      throw Exception('IAP service not available or not initialized');
    }

    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
      
      if (response.error != null) {
        throw Exception('Failed to load products: ${response.error}');
      }

      if (kDebugMode) {
        print('📦 Found ${response.productDetails.length} products:');
        for (var product in response.productDetails) {
          print('  - ${product.id}: ${product.title} (${product.price})');
        }
      }

      return response.productDetails;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting products: $e');
      rethrow;
    }
  }

  /// Generic purchase method for any product ID
  static Future<bool> purchaseProduct(String productId) async {
    if (!_isAvailable) {
      // Debug fallback - grant purchase for testing
      if (kDebugMode) {
        await _debugGrantProduct(productId);
        return true;
      }
      throw Exception('In-app purchases not available');
    }

    try {
      if (kDebugMode) print('🛒 Starting purchase for product: $productId');
      
      final products = await getProducts();
      final product = products.where((p) => p.id == productId).firstOrNull;
      
      if (product == null) {
        throw Exception('Product $productId not found. Check your product ID in Google Play Console.');
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      bool success;
      if (productId == removeAdsProductId) {
        // Non-consumable purchase (one-time purchase)
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Consumable purchase (can be purchased multiple times)
        success = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
      
      if (kDebugMode) print('🛒 Purchase initiated: $success');
      return success;
    } catch (e) {
      if (kDebugMode) print('❌ Purchase failed for $productId: $e');
      rethrow;
    }
  }

  /// Purchase remove ads (convenience method)
  static Future<bool> purchaseRemoveAds() async {
    return await purchaseProduct(removeAdsProductId);
  }

  /// Purchase hint pack (convenience method)
  static Future<bool> purchaseHintPack() async {
    return await purchaseProduct(hintPack5ProductId);
  }

  /// Restore previous purchases
  static Future<void> restorePurchases() async {
    if (!_isAvailable) {
      throw Exception('In-app purchases not available');
    }
    
    try {
      if (kDebugMode) print('🔄 Restoring purchases...');
      await _inAppPurchase.restorePurchases();
      if (kDebugMode) print('✅ Purchases restored');
    } catch (e) {
      if (kDebugMode) print('❌ Restore failed: $e');
      rethrow;
    }
  }

  /// Debug method to grant purchases for testing
  static Future<void> _debugGrantProduct(String productId) async {
    if (!kDebugMode) return; // Only in debug mode
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (productId == removeAdsProductId) {
        await prefs.setBool(_adsRemovedKey, true);
        _isAdsRemoved = true;
        print('🐛 DEBUG: Ads removed granted for testing');
      } else if (_hintAmounts.containsKey(productId)) {
        int currentHints = prefs.getInt('hint_balance') ?? 0;
        int hintsToAdd = _hintAmounts[productId]!;
        await prefs.setInt('hint_balance', currentHints + hintsToAdd);
        print('🐛 DEBUG: $hintsToAdd hints granted for testing (total: ${currentHints + hintsToAdd})');
      }
    } catch (e) {
      print('❌ Debug grant failed: $e');
    }
  }

  /// Debug method to test purchases without real money (for development)
  static Future<void> debugGrantRemoveAds() async {
    await _debugGrantProduct(removeAdsProductId);
  }

  static Future<void> debugGrantHints(int count) async {
    if (!kDebugMode) return; // Only in debug mode
    
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentHints = prefs.getInt('hint_balance') ?? 0;
      await prefs.setInt('hint_balance', currentHints + count);
      print('🐛 DEBUG: $count hints granted for testing (total: ${currentHints + count})');
    } catch (e) {
      print('❌ Debug grant failed: $e');
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }

  /// Debug method to check IAP status
  static void debugIAPStatus() {
    if (kDebugMode) {
      print('=== 🛒 IAP Debug Status ===');
      print('Initialized: $_isInitialized');
      print('Available: $_isAvailable');
      print('Ads Removed: $_isAdsRemoved');
      print('Product IDs: $_productIds');
      print('Hint Amounts: $_hintAmounts');
      print('==========================');
    }
  }
}