// lib/screens/game_screen.dart - Fixed for Remove Ads users
import 'package:flutter/material.dart';
import '../widgets/sudoku_grid.dart';
import '../services/ads_service.dart';
import '../services/ad_timer_service.dart';
import '../services/game_timer_service.dart';
import '../services/ad_helper.dart'; // FIXED: Use AdHelper instead of IAPService
import 'package:flutter/foundation.dart';
import '../widgets/completion_dialog.dart';


class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  String _difficulty = 'medium';
  Map<String, dynamic>? _savedData;
  int? _initialGameTime;
  int _gameKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // FIXED: Only start ad timer for free users
    if (AdHelper.shouldShowAds()) {
      AdTimerService.startAdTimer();
    }
  }

  @override
  void dispose() {
    AdTimerService.stopAdTimer(); // Stop when leaving game
    GameTimerService.pause(); // Pause game timer when leaving screen
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      setState(() {
        _difficulty = (args['difficulty'] ?? 'medium').toString().toLowerCase();
        _savedData = args['savedData'];
        _initialGameTime = _savedData?['gameTime'] as int?;
      });
      print('🎯 Game started with difficulty: $_difficulty ${_savedData != null ? '(resumed)' : '(new)'}');
      if (_initialGameTime != null) {
        print('⏱️ Resuming game with time: ${GameTimerService.formatTime(_initialGameTime!)}');
      }
    } else if (args is String) {
      setState(() {
        _difficulty = args.toLowerCase();
        _savedData = null;
        _initialGameTime = null;
      });
      print('🎯 Game started with difficulty: $_difficulty (legacy format)');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // FIXED: Only manage ad timer for free users
        if (AdHelper.shouldShowAds()) {
          AdTimerService.pauseAdTimer();
        }
        GameTimerService.pause();
        break;
      case AppLifecycleState.resumed:
        // FIXED: Only manage ad timer for free users
        if (AdHelper.shouldShowAds()) {
          AdTimerService.startAdTimer();
        }
        GameTimerService.resume();
        break;
      default:
        break;
    }
  }

  void _finishPuzzle() async {
    GameTimerService.pause();
    
    try {
      if (kDebugMode) {
        print('🎉 Puzzle completed in ${GameTimerService.formatTime(GameTimerService.getCurrentTime())}');
      }
      
      // FIXED: Use AdHelper to check if ads should be shown
      if (AdHelper.shouldShowAds()) {
        if (kDebugMode) {
          print('📺 Showing completion ad...');
        }
        await AdsService.showInterstitialAd();
      } else {
        if (kDebugMode) {
          print('🚫 Ads disabled - user has Remove Ads');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Ad failed: $e, proceeding anyway');
      }
    }
    
    if (mounted) {
      _showReplayDialog();
    }
  }

  void _showReplayDialog() {
    CompletionDialog.show(
      context,
      difficulty: _difficulty,
      hintsUsed: 0, // You may need to get this from SudokuGrid
      gameTime: GameTimerService.getCurrentTime(),
      onNewGame: () => _restartNewGame(),
      onContinue: () => Navigator.of(context).pop(),
    );
  }

  void _restartNewGame() {
    if (kDebugMode) {
      print('🔄 Restarting with same difficulty: $_difficulty');
    }
    
    GameTimerService.stop();
    
    setState(() {
      _savedData = null;
      _initialGameTime = null;
      _gameKey++;
    });
    
    if (kDebugMode) {
      print('✅ Game restarted with key: $_gameKey');
    }
  }

  void _showDifficultySelectionForReplay() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Difficulty'),
        content: const Text('Select difficulty for your next game:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGameWithDifficulty('easy');
            },
            child: const Text('Easy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGameWithDifficulty('medium');
            },
            child: const Text('Medium'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGameWithDifficulty('hard');
            },
            child: const Text('Hard'),
          ),
        ],
      ),
    );
  }

  void _startNewGameWithDifficulty(String newDifficulty) {
    GameTimerService.stop();
    
    if (kDebugMode) {
      print('🎯 Changing difficulty from $_difficulty to $newDifficulty');
    }
    
    setState(() {
      _difficulty = newDifficulty;
      _savedData = null;
      _initialGameTime = null;
    });
    
    if (kDebugMode) {
      print('✅ Difficulty changed to $newDifficulty, rebuilding game');
    }
  }

  void _restartGame() {
    print('🔄 Restarting game...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SUDOKU - ${_difficulty.toUpperCase()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            GameTimerService.pause();
            if (kDebugMode) print('⬅️ User went back to menu - timer paused');
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () {
              _showDifficultyInfo();
            },
          ),
        ],
      ),
      body: SudokuGrid(
        key: ValueKey(_gameKey),
        difficulty: _difficulty,
        savedGameData: _savedData,
        initialGameTime: _initialGameTime,
        onRestartGame: _restartGame,
        onPuzzleComplete: (isComplete) {
          if (isComplete) {
            _finishPuzzle();
          }
        },
      ),
    );
  }

  void _showDifficultyInfo() {
    String description;
    String cluesInfo;
    Color difficultyColor;
    IconData difficultyIcon;
    
    switch (_difficulty.toLowerCase()) {
      case 'easy':
        description = 'Perfect for beginners';
        cluesInfo = '45-49 starting clues';
        difficultyColor = Colors.green;
        difficultyIcon = Icons.sentiment_satisfied;
        break;
      case 'medium':
        description = 'Good challenge for regular players';
        cluesInfo = '35-39 starting clues';
        difficultyColor = Colors.orange;
        difficultyIcon = Icons.sentiment_neutral;
        break;
      case 'hard':
        description = 'Expert level challenge';
        cluesInfo = '25-29 starting clues';
        difficultyColor = Colors.red;
        difficultyIcon = Icons.sentiment_very_dissatisfied;
        break;
      default:
        description = 'Standard difficulty';
        cluesInfo = 'Various starting clues';
        difficultyColor = Colors.blue;
        difficultyIcon = Icons.help_outline;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              difficultyIcon,
              color: difficultyColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '${_difficulty[0].toUpperCase()}${_difficulty.substring(1)} Mode',
              style: TextStyle(
                color: difficultyColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              cluesInfo,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: difficultyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: difficultyColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: difficultyColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Current Time: ${GameTimerService.formatTime(GameTimerService.getCurrentTime())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: difficultyColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}