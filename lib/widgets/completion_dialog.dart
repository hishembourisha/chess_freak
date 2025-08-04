// lib/widgets/completion_dialog.dart - Enhanced with Remove Ads awareness
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../services/ad_helper.dart'; // ADDED: For Remove Ads logic

class CompletionDialog extends StatelessWidget {
  final String difficulty;
  final int hintsUsed;
  final int gameTime; // ADDED: Game completion time
  final VoidCallback onNewGame;
  final VoidCallback onContinue;

  const CompletionDialog({
    super.key,
    required this.difficulty,
    required this.hintsUsed,
    this.gameTime = 0, // Optional parameter
    required this.onNewGame,
    required this.onContinue,
  });

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

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
            Icons.celebration, 
            color: Colors.amber, 
            size: isTablet ? 36 : 32,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Flexible(
            child: Text(
              'Congratulations!',
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
              'You completed the puzzle!',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            
            // Game statistics
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    'Difficulty:', 
                    difficulty.toUpperCase(),
                    _getDifficultyColor(difficulty),
                    isTablet,
                  ),
                  if (gameTime > 0) ...[
                    SizedBox(height: isTablet ? 8 : 6),
                    _buildStatRow(
                      'Time:', 
                      _formatTime(gameTime),
                      Colors.blue,
                      isTablet,
                    ),
                  ],
                  SizedBox(height: isTablet ? 8 : 6),
                  _buildStatRow(
                    'Hints used:', 
                    hintsUsed.toString(),
                    hintsUsed == 0 ? Colors.green : Colors.orange,
                    isTablet,
                  ),
                ],
              ),
            ),
            
            // ADDED: Show Remove Ads status for paid users
            if (hasRemoveAds) ...[
              SizedBox(height: isTablet ? 16 : 12),
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: isTablet ? 20 : 16,
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Text(
                      'Ad-Free Experience',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Performance message
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              _getPerformanceMessage(hintsUsed, difficulty),
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            onContinue(); // This typically goes back to home
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 8,
            ),
          ),
          child: Text(
            'Home',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            onNewGame();
          },
          icon: Icon(
            Icons.refresh,
            size: isTablet ? 20 : 18,
          ),
          label: Text(
            'New Game',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getPerformanceMessage(int hintsUsed, String difficulty) {
    if (hintsUsed == 0) {
      return 'Perfect! You solved it without any hints!';
    } else if (hintsUsed <= 2) {
      return 'Great job! You only needed a few hints.';
    } else if (hintsUsed <= 5) {
      return 'Good work! Practice makes perfect.';
    } else {
      return 'Well done! Every puzzle completed is progress.';
    }
  }

  static void show(
    BuildContext context, {
    required String difficulty,
    required int hintsUsed,
    int gameTime = 0, // ADDED: Optional game time
    required VoidCallback onNewGame,
    required VoidCallback onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDialog(
        difficulty: difficulty,
        hintsUsed: hintsUsed,
        gameTime: gameTime,
        onNewGame: onNewGame,
        onContinue: onContinue,
      ),
    );
  }
}