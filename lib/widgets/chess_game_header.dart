// lib/widgets/chess_game_header.dart - Clean chess-specific header
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../services/chess_engine.dart';
import 'dart:async';

class ChessGameHeader extends StatefulWidget {
  final Difficulty difficulty;
  final VoidCallback? onRestartGame;
  final int? initialTime; // For loading saved games
  
  const ChessGameHeader({
    super.key,
    required this.difficulty,
    this.onRestartGame,
    this.initialTime,
  });

  @override
  State<ChessGameHeader> createState() => _ChessGameHeaderState();
}

class _ChessGameHeaderState extends State<ChessGameHeader> {
  int _currentTime = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  void _initializeTimer() {
    // Set initial time if provided (for loaded games)
    _currentTime = widget.initialTime ?? 0;
    
    // Start the timer
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _currentTime = 0;
    });
    _startTimer();
  }

  @override
  void didUpdateWidget(ChessGameHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset timer when difficulty changes or new game starts
    if (oldWidget.difficulty != widget.difficulty || 
        oldWidget.initialTime != widget.initialTime) {
      _initializeTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
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
                  _getDifficultyDisplayName(widget.difficulty),
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
                  _formatTime(_currentTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade700,
                    fontFamily: 'monospace', // Monospace numbers
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

  String _getDifficultyDisplayName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'EASY';
      case Difficulty.intermediate:
        return 'MEDIUM';
      case Difficulty.advanced:
        return 'HARD';
      case Difficulty.grandmaster:
        return 'GRANDMASTER';
    }
  }

  // Get difficulty color and icon based on difficulty level
  Map<String, dynamic> _getDifficultyStyle(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return {
          'color': Colors.green,
          'backgroundColor': Colors.green.shade50,
          'borderColor': Colors.green.shade200,
          'icon': Icons.sentiment_satisfied,
        };
      case Difficulty.intermediate:
        return {
          'color': Colors.orange,
          'backgroundColor': Colors.orange.shade50,
          'borderColor': Colors.orange.shade200,
          'icon': Icons.sentiment_neutral,
        };
      case Difficulty.advanced:
        return {
          'color': Colors.red,
          'backgroundColor': Colors.red.shade50,
          'borderColor': Colors.red.shade200,
          'icon': Icons.sentiment_very_dissatisfied,
        };
      case Difficulty.grandmaster:
        return {
          'color': Colors.purple,
          'backgroundColor': Colors.purple.shade50,
          'borderColor': Colors.purple.shade200,
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
            Text('Restart Chess Game'),
          ],
        ),
        content: const Text(
          'Are you sure you want to restart the chess game? All progress will be lost.',
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
              
              // Reset timer when restarting
              _resetTimer();
              
              // Call restart callback
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

  // Getter to access current time for saving games
  int get currentTime => _currentTime;

  // Method to pause/resume timer (useful for game pause functionality)
  void pauseTimer() => _stopTimer();
  void resumeTimer() => _startTimer();
}