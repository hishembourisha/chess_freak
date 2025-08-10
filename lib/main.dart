// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/iap_service.dart'; 
import 'helpers/ad_helper.dart';
import 'services/sound_service.dart';
import 'services/vibration_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');
  } catch (e) {
    print('⚠️ Could not load .env file: $e');
    print('📱 Using test ad unit IDs');
  }
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await _initializeServices();
  
  runApp(const ChessFreakApp());
}

Future<void> _initializeServices() async {
  print('\n=== 🔧 Initializing Chess Freak Services ===');
  
  // Initialize Sound Service
  try {
    await SoundService.initialize();
    print('✅ Sound service initialized');
  } catch (e) {
    print('❌ Failed to initialize sound: $e');
  }
  
  // Initialize Vibration Service
  try {
    await VibrationService.initialize();
    print('✅ Vibration service initialized');
  } catch (e) {
    print('❌ Failed to initialize vibration: $e');
  }
  
  // Initialize IAP Service (for Remove Ads)
  try {
    await IAPService.initialize();
    print('✅ IAP service initialized');
  } catch (e) {
    print('❌ Failed to initialize IAP: $e');
  }
  
  // Initialize Ad Helper
  try {
    await AdHelper.initialize();
    print('✅ AdHelper initialized');
  } catch (e) {
    print('❌ Failed to initialize AdHelper: $e');
  }
  
  // Initialize Ads Service (only if user should see ads)
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
  
  if (kDebugMode) {
    print('\n=== 🎯 Chess Freak Ready ===');
    SoundService.debugSoundState();
    AdHelper.debugAdStatus();
    IAPService.debugIAPStatus(); 
    print('===========================\n');
  }
}

class ChessFreakApp extends StatelessWidget {
  const ChessFreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Freak',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        primarySwatch: MaterialColor(
          0xFF8D6E63, // Brown theme for chess
          <int, Color>{
            50: const Color(0xFFF3E5AB),
            100: const Color(0xFFEFDECD),
            200: const Color(0xFFD7CCC8),
            300: const Color(0xFFBCAAA4),
            400: const Color(0xFFA1887F),
            500: const Color(0xFF8D6E63),
            600: const Color(0xFF8D6E63),
            700: const Color(0xFF6D4C41),
            800: const Color(0xFF5D4037),
            900: const Color(0xFF3E2723),
          },
        ),
        useMaterial3: true,
        
        fontFamily: 'Roboto Condensed',
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
        
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.brown[600],
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Roboto Condensed',
            letterSpacing: 1.0,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        
        // Chess-specific styling
        iconTheme: IconThemeData(
          color: Colors.brown[700],
        ),
        
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.brown;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.brown.withValues(alpha: 0.5);
            }
            return Colors.grey.withValues(alpha: 0.3);
          }),
        ),
      ),
      
      home: const HomeScreen(),
    );
  }
}