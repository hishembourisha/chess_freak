// lib/widgets/hint_dialog.dart - Enhanced with Remove Ads awareness
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../services/ads_service.dart';
import '../services/ad_helper.dart'; // ADDED: For Remove Ads logic
import '../screens/hint_store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HintDialog extends StatelessWidget {
  final Function(int) onHintsEarned;

  const HintDialog({
    super.key,
    required this.onHintsEarned,
  });

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    
    // ADDED: Check if user has Remove Ads
    final hasRemoveAds = !AdHelper.shouldShowAds();
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.lightbulb_outline, 
            color: Colors.amber, 
            size: isTablet ? 32 : 28,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Flexible(
            child: Text(
              'Need a Hint?',
              style: TextStyle(fontSize: isTablet ? 20 : 18),
            ),
          ),
        ],
      ),
      content: Container(
        width: isLargeTablet ? 400 : (isTablet ? 350 : 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You don\'t have any hints available.',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            
            Text(
              'Choose how to get more hints:',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            
            // FIXED: Different options for free vs paid users
            if (hasRemoveAds) ...[
              // Paid users: Only show purchase option
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      color: Colors.blue,
                      size: isTablet ? 32 : 28,
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Text(
                      'Purchase Hints',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: isTablet ? 8 : 4),
                    Text(
                      'Buy hint packages from the store',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 11,
                        color: Colors.blue.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Ad-Free User',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Free users: Show both options
              Row(
                children: [
                  // Watch Ad option
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            color: Colors.green,
                            size: isTablet ? 32 : 28,
                          ),
                          SizedBox(height: isTablet ? 8 : 6),
                          Text(
                            'Watch Ad',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          SizedBox(height: isTablet ? 4 : 2),
                          Text(
                            'Get 1 hint',
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 9,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  // Purchase option
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: Colors.blue,
                            size: isTablet ? 32 : 28,
                          ),
                          SizedBox(height: isTablet ? 8 : 6),
                          Text(
                            'Buy Hints',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: isTablet ? 4 : 2),
                          Text(
                            'Hint packages',
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 9,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 8,
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
        ),
        
        // FIXED: Different buttons for free vs paid users
        if (hasRemoveAds) ...[
          // Paid users: Only show purchase button
          ElevatedButton.icon(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
              _navigateToHintStore(context);
            },
            icon: Icon(
              Icons.shopping_cart,
              size: isTablet ? 20 : 18,
            ),
            label: Text(
              'Buy Hints',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 8,
              ),
            ),
          ),
        ] else ...[
          // Free users: Show both buttons
          ElevatedButton.icon(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
              _watchAdForHint(context);
            },
            icon: Icon(
              Icons.play_circle_outline,
              size: isTablet ? 20 : 18,
            ),
            label: Text(
              'Watch Ad',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 8,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 12 : 8),
          ElevatedButton.icon(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
              _navigateToHintStore(context);
            },
            icon: Icon(
              Icons.shopping_cart,
              size: isTablet ? 20 : 18,
            ),
            label: Text(
              'Buy Hints',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 8,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToHintStore(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HintStoreScreen(),
      ),
    );
  }

  Future<void> _watchAdForHint(BuildContext context) async {
    // FIXED: Only for free users
    if (!AdHelper.canShowRewardedAd()) {
      // This shouldn't happen for paid users, but handle gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ads not available. Please purchase hints instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      await AdsService.showRewardedAd(onReward: () async {
        // Grant hint
        final prefs = await SharedPreferences.getInstance();
        final currentBalance = prefs.getInt('hint_balance') ?? 0;
        await prefs.setInt('hint_balance', currentBalance + 1);
        
        // Success vibration
        VibrationService.medium();
        
        // Notify parent
        onHintsEarned(1);
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You earned 1 hint! New balance: ${currentBalance + 1}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    } catch (e) {
      // Error vibration
      VibrationService.errorEntry();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static void show(
    BuildContext context, {
    required Function(int) onHintsEarned,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => HintDialog(
        onHintsEarned: onHintsEarned,
      ),
    );
  }
}