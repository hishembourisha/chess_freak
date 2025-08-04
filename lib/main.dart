// main.dart - Fixed to respect Remove Ads purchase with proper initialization order
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sudoku_app/screens/home_screen.dart';
import 'package:sudoku_app/services/ads_service.dart';
import 'package:sudoku_app/services/iap_service.dart';
import 'package:sudoku_app/services/ad_helper.dart'; // FIXED: Import updated AdHelper
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for ad unit IDs
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');
  } catch (e) {
    print('⚠️ Could not load .env file: $e');
    print('📱 Using test ad unit IDs');
  }
  
  // Set preferred orientations (portrait only for better Sudoku experience)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize services with proper order
  await _initializeServices();
  
  // Run the app
  runApp(const SudokuApp());
}

Future<void> _initializeServices() async {
  // 1. Initialize basic services first
  try {
    await SoundService.initialize();
    print('✅ Sound service initialized');
  } catch (e) {
    print('❌ Failed to initialize sound: $e');
  }
  
  try {
    await VibrationService.initialize();
    print('✅ Vibration service initialized');
  } catch (e) {
    print('❌ Failed to initialize vibration: $e');
  }
  
  // 2. CRITICAL: Initialize IAP service FIRST to load purchase state
  try {
    await IAPService.initialize();
    print('✅ IAP service initialized');
    
    // Give IAP service time to process any pending purchases
    await Future.delayed(const Duration(milliseconds: 500));
  } catch (e) {
    print('❌ Failed to initialize IAP: $e');
  }
  
  // 3. Initialize AdHelper after IAP service has loaded purchase state
  try {
    await AdHelper.initialize();
    print('✅ AdHelper initialized');
  } catch (e) {
    print('❌ Failed to initialize AdHelper: $e');
  }
  
  // 4. FIXED: Only initialize ads service for free users AFTER checking purchase state
  try {
    if (AdHelper.shouldShowAds()) {
      await AdsService.initialize();
      print('✅ Ads service initialized for free user');
    } else {
      print('🚫 Ads service skipped - user has Remove Ads');
    }
  } catch (e) {
    print('❌ Failed to initialize ads: $e');
  }
  
  // 5. Final debug output (only in debug mode)
  if (kDebugMode) {
    print('\n=== 🔧 Service Initialization Complete ===');
    SoundService.debugSoundState();
    AdHelper.debugAdStatus();
    IAPService.debugIAPStatus();
    print('=========================================\n');
  }
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Freak',
      debugShowCheckedModeBanner: false,
      
      // Enhanced theme
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        
        // Custom font family
        fontFamily: 'Roboto Condensed', // Bold, game-like font
        
        // Color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        
        // AppBar theme
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: 'Roboto Condensed',
            letterSpacing: 1.0,
          ),
        ),
        
        // Button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      
      // Home screen
      home: const HomeScreen(),
    );
  }
}