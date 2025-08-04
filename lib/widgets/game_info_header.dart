// lib/widgets/game_info_header.dart - Updated without difficulty text (since it's now in app bar)
import 'package:flutter/material.dart';
import 'error_counter.dart';
import '../services/vibration_service.dart';
import '../services/game_timer_service.dart';
import 'package:flutter/foundation.dart';

class GameInfoTop extends StatefulWidget {
  final String difficulty;
  final VoidCallback? onRestartGame;
  final int? initialTime; // For loading saved games
  
  const GameInfoTop({
    super.key,
    required this.difficulty,
    this.onRestartGame,
    this.initialTime,
  });

  @override
  State<GameInfoTop> createState() => _GameInfoTopState();
}

class _GameInfoTopState extends State<GameInfoTop> {
  int _currentTime = 0;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  void _initializeTimer() {
    // Set initial time if provided (for loaded games)
    if (widget.initialTime != null) {
      GameTimerService.setTime(widget.initialTime!);
      _currentTime = widget.initialTime!;
    } else {
      // For new games, ensure timer starts at 0
      GameTimerService.stop();
      _currentTime = 0;
    }
    
    // Start the timer with callback to update UI
    GameTimerService.start(onTimeUpdate: (seconds) {
      if (mounted) {
        setState(() {
          _currentTime = seconds;
        });
      }
    });
  }

  @override
  void didUpdateWidget(GameInfoTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // FIXED: Reset timer when difficulty changes or new game starts
    if (oldWidget.difficulty != widget.difficulty || 
        oldWidget.initialTime != widget.initialTime) {
      if (kDebugMode) {
        print('🔄 Difficulty changed or new game: ${oldWidget.difficulty} → ${widget.difficulty}');
      }
      _initializeTimer();
    }
  }

  @override
  void dispose() {
    // Don't stop the timer here - let the game screen manage it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get difficulty styling
    final difficultyStyle = _getDifficultyStyle(widget.difficulty);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT side - Colored Difficulty Frame
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: difficultyStyle['backgroundColor'],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: difficultyStyle['borderColor'],
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: difficultyStyle['color'].withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  difficultyStyle['icon'],
                  size: 16,
                  color: difficultyStyle['color'],
                ),
                const SizedBox(width: 6),
                Text(
                  widget.difficulty.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: difficultyStyle['color'],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // CENTER - Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  GameTimerService.formatTime(_currentTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade700,
                    fontFeatures: const [FontFeature.tabularFigures()], // Monospace numbers
                  ),
                ),
              ],
            ),
          ),
          
          // RIGHT side - Restart button
          InkWell(
            onTap: () => _showRestartDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.refresh,
                size: 20,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get difficulty color and icon based on difficulty level
  Map<String, dynamic> _getDifficultyStyle(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return {
          'color': Colors.green,
          'backgroundColor': Colors.green.shade50,
          'borderColor': Colors.green.shade200,
          'icon': Icons.sentiment_satisfied,
        };
      case 'medium':
        return {
          'color': Colors.orange,
          'backgroundColor': Colors.orange.shade50,
          'borderColor': Colors.orange.shade200,
          'icon': Icons.sentiment_neutral,
        };
      case 'hard':
        return {
          'color': Colors.red,
          'backgroundColor': Colors.red.shade50,
          'borderColor': Colors.red.shade200,
          'icon': Icons.sentiment_very_dissatisfied,
        };
      default:
        return {
          'color': Colors.blue,
          'backgroundColor': Colors.blue.shade50,
          'borderColor': Colors.blue.shade200,
          'icon': Icons.help_outline,
        };
    }
  }

  void _showRestartDialog(BuildContext context) {
    VibrationService.buttonPressed();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restart Game'),
          ],
        ),
        content: const Text(
          'Are you sure you want to restart the game? All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
              
              // FIXED: Properly reset timer when restarting
              GameTimerService.stop();
              setState(() {
                _currentTime = 0;
              });
              
              // Call restart which will start a new timer
              widget.onRestartGame?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

class GameInfoBottom extends StatelessWidget {
  final int hintBalance;
  final bool noteMode;
  final int errorCount;
  final int maxErrors;
  
  const GameInfoBottom({
    super.key,
    required this.hintBalance,
    required this.noteMode,
    required this.errorCount,
    this.maxErrors = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left - Hints
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text(
                'Hints: $hintBalance',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          
          // Center - Error counter
          ErrorCounter(
            errorCount: errorCount,
            maxErrors: maxErrors,
          ),
          
          // Right - Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: noteMode ? Colors.green.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              noteMode ? 'NOTE MODE' : 'NUMBER MODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: noteMode ? Colors.green.shade800 : Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}