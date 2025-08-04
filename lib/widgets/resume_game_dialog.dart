// lib/widgets/resume_game_dialog.dart
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../services/game_save_service.dart';

class ResumeGameDialog extends StatelessWidget {
  final Map<String, dynamic> gameInfo;
  final VoidCallback onResumeGame;
  final VoidCallback onNewGame;

  const ResumeGameDialog({
    super.key,
    required this.gameInfo,
    required this.onResumeGame,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    final difficulty = gameInfo['difficulty'] as String;
    final hintsUsed = gameInfo['hintsUsed'] as int;
    final errorCount = gameInfo['errorCount'] as int;
    final timestamp = gameInfo['timestamp'] as DateTime;
    final timeAgo = GameSaveService.getTimeAgo(timestamp);
    
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.save, color: Colors.blue, size: 28),
          SizedBox(width: 8),
          Text('Resume Game?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You have a saved game in progress.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          // Game details card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getDifficultyIcon(difficulty),
                      color: _getDifficultyColor(difficulty),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Difficulty: ${difficulty[0].toUpperCase()}${difficulty.substring(1)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Last played: $timeAgo',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Hints used: $hintsUsed',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.warning, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Errors: $errorCount/3',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Text(
            'Would you like to resume this game or start a new one?',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            onNewGame();
          },
          child: const Text('New Game'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            VibrationService.buttonPressed();
            Navigator.of(context).pop();
            onResumeGame();
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Icons.sentiment_satisfied;
      case 'medium':
        return Icons.sentiment_neutral;
      case 'hard':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help;
    }
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
        return Colors.grey;
    }
  }

  static void show(
    BuildContext context, {
    required Map<String, dynamic> gameInfo,
    required VoidCallback onResumeGame,
    required VoidCallback onNewGame,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ResumeGameDialog(
        gameInfo: gameInfo,
        onResumeGame: onResumeGame,
        onNewGame: onNewGame,
      ),
    );
  }
}