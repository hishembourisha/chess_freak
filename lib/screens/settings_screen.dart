// settings_screen.dart - Fixed version with proper AdHelper integration
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/iap_service.dart';
import '../helpers/ad_helper.dart'; // ADDED: Import AdHelper
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import 'package:flutter/foundation.dart';
import '../services/ad_timer_service.dart';
import '../services/ads_service.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true; 
  bool _vibrationEnabled = true;
  bool _isLoading = false;
  bool _adsRemoved = false;
  String _removeAdsPrice = 'Loading...';

  // Privacy policy URL
  static const String _privacyPolicyUrl = 'https://sites.google.com/view/chessfreakprivacypolicy';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

Future<void> _loadSettings() async {
  try {
    await SoundService.initialize();
    await VibrationService.initialize();
    
    // CRITICAL FIX: Force refresh AdHelper state
    await AdHelper.refreshStatus();
    
    try {
      await IAPService.initialize();
    } catch (e) {
      print('IAP not available: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _soundEnabled = SoundService.isSoundEnabled;
      _musicEnabled = SoundService.isMusicEnabled;
      _vibrationEnabled = VibrationService.isVibrationEnabled;
      
      // CRITICAL FIX: Check SharedPreferences directly
      _adsRemoved = prefs.getBool('ads_removed') ?? false;
    });
    
    await _loadRemoveAdsPrice();
  } catch (e) {
    _showErrorSnackBar('Failed to load settings: $e');
  }
}

  Future<void> _toggleSound(bool value) async {
    try {
      await SoundService.setSoundEnabled(value);

      if (!mounted) return;
      setState(() => _soundEnabled = value);

      // Play test sound if enabling
      if (value) {
        await SoundService.playButton();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save sound setting: $e');
    }
  }

  Future<void> _toggleMusic(bool value) async {
    try {
      await SoundService.setMusicEnabled(value);

      if (!mounted) return;
      setState(() => _musicEnabled = value);
    } catch (e) {
      _showErrorSnackBar('Failed to save background music setting: $e');
    }
  }

  Future<void> _toggleVibration(bool value) async {
    try {
      await VibrationService.setVibrationEnabled(value);

      if (!mounted) return;
      setState(() => _vibrationEnabled = value);

      // Test vibration if enabling
      if (value) {
        await VibrationService.test();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save vibration setting: $e');
    }
  }

  // Load remove ads price
  Future<void> _loadRemoveAdsPrice() async {
    try {
      if (IAPService.isAvailable) {
        final products = await IAPService.getProducts();
        final removeAdsProduct = products.where((p) => p.id == IAPService.removeAdsProductId).firstOrNull;
        
        if (removeAdsProduct != null && mounted) {
          setState(() {
            _removeAdsPrice = removeAdsProduct.price;
          });
        } else if (mounted) {
          setState(() {
            _removeAdsPrice = 'Price unavailable';
          });
        }
      } else if (mounted) {
        setState(() {
          _removeAdsPrice = 'Not available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _removeAdsPrice = 'Price unavailable';
        });
      }
      if (kDebugMode) print('Error loading remove ads price: $e');
    }
  }

  // Open privacy policy
  Future<void> _openPrivacyPolicy() async {
    VibrationService.buttonPressed();
    
    try {
      final Uri url = Uri.parse(_privacyPolicyUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Opens in browser
        );
      } else {
        _showErrorSnackBar('Could not open privacy policy');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open privacy policy: $e');
    }
  }

  // Purchase Remove Ads - FIXED: Remove the immediate check that causes false error
  Future<void> _purchaseRemoveAds() async {
    VibrationService.buttonPressed();
    setState(() => _isLoading = true);

    try {
      if (!IAPService.isAvailable) {
        _showDeviceNotSupportedDialog();
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing remove ads purchase...'),
              ],
            ),
          ),
        );
      }

      bool purchaseSuccessful = await IAPService.purchaseRemoveAds();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;

      if (purchaseSuccessful) {
        // FIXED: Don't check SharedPreferences immediately!
        // Just show that purchase was initiated and start checking for completion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase initiated successfully. Complete the purchase in Google Play.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Start checking for completion
        _checkForPurchaseCompletion();
      } else {
        VibrationService.errorEntry();
        _showErrorSnackBar('Failed to initiate purchase. Please try again.');
      }

    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      VibrationService.errorEntry();
      _showErrorSnackBar('Purchase failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Check for purchase completion and handle ad removal
  void _checkForPurchaseCompletion() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check if purchase completed
      final prefs = await SharedPreferences.getInstance();
      bool adsRemoved = prefs.getBool('ads_removed') ?? false;

      if (adsRemoved && !_adsRemoved) {
        // Purchase completed! Now do the ad cleanup
        timer.cancel();
        
        // Payment confirmed and saved - proceed
        await AdHelper.refreshStatus();
        AdTimerService.stopAdTimer();
        AdsService.dispose();
        setState(() => _adsRemoved = true);
        VibrationService.medium(); // Success vibration
        _showRemoveAdsSuccessDialog();
      }

      // Stop checking after 2 minutes
      if (timer.tick > 60) {
        timer.cancel();
      }
    });
  }

  // Success dialog for remove ads
  void _showRemoveAdsSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text('Ads Removed!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉 Thank you for your support!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('All advertisements have been permanently removed from the app.'),
            SizedBox(height: 12),
            Text(
              'Enjoy your ad-free Chess experience!',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showDeviceNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchases Not Available'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In-app purchases are not available on this device.'),
            SizedBox(height: 8),
            Text('This could be because:'),
            Text('• Device doesn\'t support Google Play Billing'),
            Text('• App is not published in Play Store yet'),
            Text('• Testing on emulator without Google Play'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Improved Remove Ads dialog with price
  void _showRemoveAdsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Ads'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🚫 Remove all advertisements', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('✨ Support the developer', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('🎮 Uninterrupted gaming experience', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Price: $_removeAdsPrice',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Colors.green,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'One-time purchase - ads removed forever!',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _purchaseRemoveAds();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Remove Ads • $_removeAdsPrice'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Game Settings Section
                const Text(
                  'Game Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _soundEnabled,
                        title: const Text('Sound Effects'),
                        subtitle: const Text('Enable or disable button sounds and game effects'),
                        secondary: const Icon(Icons.volume_up),
                        onChanged: _toggleSound,
                      ),
                      SwitchListTile(
                        value: _musicEnabled,
                        title: const Text('Background Music'),
                        subtitle: const Text('Enable or disable background music (independent of sound effects)'),
                        secondary: const Icon(Icons.music_note),
                        onChanged: _toggleMusic,
                      ),
                      SwitchListTile(
                        value: _vibrationEnabled,
                        title: const Text('Vibration'),
                        subtitle: const Text('Enable or disable haptic feedback'),
                        secondary: const Icon(Icons.vibration),
                        onChanged: _toggleVibration,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Purchases Section - Updated
                const Text(
                  'Purchases',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      // Remove Ads Section - Improved
                      ListTile(
                        leading: Icon(
                          _adsRemoved ? Icons.check_circle : Icons.block,
                          color: _adsRemoved ? Colors.green : Colors.orange,
                        ),
                        title: Text(_adsRemoved ? 'Ads Removed ✓' : 'Remove Ads'),
                        subtitle: Text(_adsRemoved 
                            ? 'Thank you for your support! 🎉' 
                            : (_removeAdsPrice == 'Loading...' 
                                ? 'One-time purchase • Ad-free forever' 
                                : 'One-time purchase • Ad-free forever • $_removeAdsPrice')),
                        trailing: _adsRemoved 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: (_isLoading || _removeAdsPrice == 'Loading...') ? null : _showRemoveAdsDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(_removeAdsPrice == 'Loading...' ? 'Loading...' : 'Remove'),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // About Section
                const Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About This Game'),
                        subtitle: const Text('Version 1.0.0\nTap for more details'),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Chess Freak',
                            applicationVersion: '1.0.0',
                            children: [
                              const Text('Chess Freak is your ultimate destination for Chess games. Enjoy a seamless and challenging experience!'),
                            ],
                          );
                        },
                      ),
                      // Privacy Policy Link
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('View our privacy policy'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: _openPrivacyPolicy,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ADDED: Debug section for development
                if (kDebugMode) ...[
                  const Text(
                    'Debug (Development Only)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.bug_report),
                          title: const Text('Debug Grant Remove Ads'),
                          subtitle: const Text('Grant Remove Ads for testing'),
                          trailing: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              await IAPService.debugGrantRemoveAds();
                              await AdHelper.refreshStatus();
                              await _loadSettings();
                              _showErrorSnackBar('Debug: Remove Ads granted');
                            },
                            child: const Text('Grant'),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text('Debug AdHelper Status'),
                          subtitle: const Text('Print current ad status to console'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              AdHelper.debugAdStatus();
                              IAPService.debugIAPStatus();
                              _showErrorSnackBar('Debug info printed to console');
                            },
                            child: const Text('Debug'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}