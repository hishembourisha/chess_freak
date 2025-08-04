// lib/widgets/error_dialog.dart - Fixed for Remove Ads users
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../services/ads_service.dart';
import '../services/ad_helper.dart'; // ADDED: For Remove Ads logic

class ErrorDialog extends StatelessWidget {
  final int errorCount;
  final VoidCallback onWatchAd;
  final VoidCallback onGameOver;

  const ErrorDialog({
    super.key,
    required this.errorCount,
    required this.onWatchAd,
    required this.onGameOver,
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
            Icons.warning, 
            color: Colors.red, 
            size: isTablet ? 36 : 32,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Flexible(
            child: Text(
              errorCount == 3 ? "Game Over!" : "Error!",
              style: TextStyle(fontSize: isTablet ? 22 : 18),
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
              // FIXED: Different messages for free vs paid users
              errorCount == 3 
                  ? (hasRemoveAds 
                      ? 'You\'ve made 3 errors! Your errors will be automatically reset.'
                      : 'You\'ve made 3 errors! Watch an ad to continue playing and reset your error count.')
                  : 'You\'ve made $errorCount out of 3 allowed errors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isTablet ? 18 : 16),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            
            // Error indicators with responsive sizing
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 6 : 4,
                  ),
                  child: Icon(
                    index < errorCount ? Icons.close : Icons.circle_outlined,
                    color: index < errorCount ? Colors.red : Colors.grey,
                    size: isTablet ? 28 : 24,
                  ),
                );
              }),
            ),
            
            if (errorCount < 3) ...[
              SizedBox(height: isTablet ? 12 : 8),
              Text(
                '${3 - errorCount} error${3 - errorCount == 1 ? '' : 's'} remaining',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // ADDED: Show Remove Ads benefit message for paid users
            if (errorCount == 3 && hasRemoveAds) ...[
              SizedBox(height: isTablet ? 16 : 12),
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: isTablet ? 20 : 16,
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Expanded(
                      child: Text(
                        'Ad-free gaming active!',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: errorCount == 3 ? [
        TextButton(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            onGameOver();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 8,
            ),
          ),
          child: Text(
            'Quit Game',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            
            // FIXED: Different behavior for free vs paid users
            if (hasRemoveAds) {
              // Paid users: automatic continue
              onWatchAd(); // Reset errors and continue
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Errors reset! Ad-free gaming activated.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              // Free users: watch ad
              await _watchAdToContinue(context);
            }
          },
          icon: Icon(
            hasRemoveAds ? Icons.refresh : Icons.play_circle_outline,
            size: isTablet ? 20 : 18,
          ),
          label: Text(
            hasRemoveAds ? 'Continue (Ad-Free)' : 'Continue Playing',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasRemoveAds ? Colors.blue : Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 8,
            ),
          ),
        ),
      ] : [
        ElevatedButton(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20,
              vertical: isTablet ? 12 : 8,
            ),
          ),
          child: Text(
            'Continue',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
        ),
      ],
    );
  }

  Future<void> _watchAdToContinue(BuildContext context) async {
    // FIXED: Only for free users
    if (!AdHelper.canShowRewardedAd()) {
      // This shouldn't happen, but handle gracefully
      onWatchAd();
      return;
    }
    
    try {
      await AdsService.showRewardedAd(onReward: () {
        // Success vibration
        VibrationService.medium();
        
        // Reset errors and continue
        onWatchAd();
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errors reset! You can continue playing.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } catch (e) {
      // Error vibration
      VibrationService.errorEntry();
      
      if (context.mounted) {
        // FIXED: Show dialog with restart option when ad fails
        _showAdFailedDialog(context, e.toString());
      }
    }
  }

  void _showAdFailedDialog(BuildContext context, String error) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: isTablet ? 28 : 24,
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Flexible(
              child: Text(
                'Ad Not Available',
                style: TextStyle(fontSize: isTablet ? 20 : 18),
              ),
            ),
          ],
        ),
        content: Container(
          width: isLargeTablet ? 350 : (isTablet ? 300 : 250),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load ad to continue the game.',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Text(
                'The game will restart automatically.',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              // ADDED: Suggest Remove Ads
              SizedBox(height: isTablet ? 16 : 12),
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Tip: Purchase "Remove Ads" for unlimited error resets!',
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 11,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
              // FIXED: Auto-restart the game when ad fails
              onWatchAd(); // This will reset errors and restart
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 12 : 8,
              ),
            ),
            child: Text(
              'Restart Game',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required int errorCount,
    required VoidCallback onWatchAd,
    required VoidCallback onGameOver,
  }) {
    showDialog(
      context: context,
      barrierDismissible: errorCount < 3, // Can't dismiss if game over
      builder: (context) => ErrorDialog(
        errorCount: errorCount,
        onWatchAd: onWatchAd,
        onGameOver: onGameOver,
      ),
    );
  }
}