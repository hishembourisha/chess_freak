// lib/screens/chess_game_screen.dart - Enhanced with working ad timer
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // NEW: Import for kDebugMode
import '../services/chess_engine.dart';
import '../widgets/chess_board.dart';
import '../widgets/captured_pieces_widget.dart';
import '../services/chess_save_service.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../widgets/chess_game_info_widget.dart';
import '../helpers/ad_helper.dart';
import '../services/game_timer_service.dart';
import '../services/ad_timer_service.dart'; // NEW: Import ad timer
import '../services/ads_service.dart';       // NEW: Import ads service
import '../widgets/banner_ad_widget.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> with WidgetsBindingObserver {
  late ChessEngine _engine;
  late bool _isPlayerWhite;
  Difficulty _difficulty = Difficulty.beginner;
  Map<String, dynamic>? _savedGameData;
  int? _initialGameTime;
  bool _gameStarted = false;
  bool _adsRemoved = false;
  bool _isColorSelected = false;
  int _gameKey = 0;
  
  // Game over dialog management
  bool _isGameOverDialogShowing = false;
  bool _gameOverDetected = false;
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize with safe defaults
    _isPlayerWhite = true;
    _engine = ChessEngine(difficulty: _difficulty);
    
    _loadAdStatus();
    _ensureBackgroundMusicPlaying();
    
    // NEW: Initialize ads and start timer
    _initializeAds();
  }

  @override
  void dispose() {
    GameTimerService.stop();
    AdTimerService.stopAdTimer(); // NEW: Stop ad timer when leaving
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // NEW: Initialize ads and start timer
  Future<void> _initializeAds() async {
    try {
      // Initialize AdHelper first
      await AdHelper.initialize();
      
      // Initialize AdsService
      await AdsService.initialize();
      
      // Start ad timer only for free users
      if (AdHelper.shouldShowAds()) {
        AdTimerService.startAdTimer();
        print('🕐 Ad timer started for chess game');
      } else {
        print('🚫 Ad timer not started - user has Remove Ads');
      }
      
      // Debug ad status
      AdHelper.debugAdStatus();
      AdTimerService.debugTimerStatus();
    } catch (e) {
      print('❌ Error initializing ads: $e');
    }
  }

  Future<void> _ensureBackgroundMusicPlaying() async {
    try {
      if (SoundService.isMusicEnabled && !SoundService.isMusicPlaying) {
        print('🎵 Starting background music on chess game screen');
        await SoundService.startBackgroundMusic();
      }
    } catch (e) {
      print('❌ Error starting background music: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      setState(() {
        _difficulty = args['difficulty'] ?? Difficulty.beginner;
        _savedGameData = args['savedGameData'];
        _initialGameTime = _savedGameData?['gameTime'] as int?;
        
        if (_savedGameData != null) {
          print('🔄 Resuming game with difficulty: $_difficulty');
          _resumeGameFromData();
        } else {
          print('🎮 Starting new game with difficulty: $_difficulty');
          _isColorSelected = false;
        }
      });
    }
  }

  void _resumeGameFromData() {
    try {
      final savedEngine = ChessSaveService.restoreGameState(_savedGameData!);
      if (savedEngine != null) {
        _engine = savedEngine;
        _isPlayerWhite = _savedGameData!['isPlayerWhite'] ?? true;
        _gameStarted = true;
        _isColorSelected = true;
        
        print('✅ Successfully resumed chess game');
        print('🎯 Playing as: ${_isPlayerWhite ? 'White' : 'Black'}');
      } else {
        print('❌ Failed to restore saved game, falling back to new game');
        _isColorSelected = false;
      }
    } catch (e) {
      print('❌ Error resuming game: $e');
      _isColorSelected = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_gameStarted && !_engine.isGameOver) {
          GameTimerService.pause();
        }
        // NEW: Pause ad timer when app is paused
        AdTimerService.pauseAdTimer();
        SoundService.pauseBackgroundMusic();
        _autoSaveGame();
        break;
      case AppLifecycleState.resumed:
        if (_gameStarted && !_engine.isGameOver) {
          GameTimerService.resume();
        }
        _ensureBackgroundMusicPlaying();
        _loadAdStatus();
        
        // NEW: Resume ad timer if still free user
        if (AdHelper.shouldShowAds() && !AdTimerService.isTimerActive) {
          AdTimerService.startAdTimer();
          print('🔄 Ad timer resumed after app resume');
        }
        break;
      default:
        break;
    }
  }

  Future<void> _loadAdStatus() async {
    try {
      await AdHelper.refreshStatus();
      if (mounted) {
        setState(() {
          _adsRemoved = !AdHelper.shouldShowAds();
        });
        
        // NEW: Stop ad timer if user now has Remove Ads
        if (_adsRemoved && AdTimerService.isTimerActive) {
          AdTimerService.stopAdTimer();
          print('🛑 Ad timer stopped - user now has Remove Ads');
        }
        // Start ad timer if user is now free
        else if (!_adsRemoved && !AdTimerService.isTimerActive) {
          AdTimerService.startAdTimer();
          print('▶️ Ad timer started - user is now free');
        }
      }
    } catch (e) {
      print('Error loading ad status: $e');
    }
  }

  void _createNewGame({required bool isPlayerWhite}) {
    setState(() {
      _isPlayerWhite = isPlayerWhite;
      _isColorSelected = true;
      _gameStarted = false;
      _gameKey++;
      _isGameOverDialogShowing = false;
      _gameOverDetected = false;
    });
    
    _engine = ChessEngine(difficulty: _difficulty);
    GameTimerService.stop();
    
    SoundService.playGameStart();
    
    print('🎮 Created new chess game');
    print('🎯 Player is playing as: ${_isPlayerWhite ? 'White' : 'Black'}');
    
    // NEW: Show game transition ad when starting new game
    _showGameTransitionAd();
    
    if (!_isPlayerWhite) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _gameStarted = true;
          });
        }
      });
    }
  }

  // NEW: Show ad when game finishes
  void _showGameFinishAd() {
    AdTimerService.showGameFinishAd();
  }

  // NEW: Show ad when transitioning between games
  void _showGameTransitionAd() {
    AdTimerService.showGameTransitionAd();
  }

  void _onMoveMade(ChessMove move) {
    print('📝 Move made: ${move.fromRow},${move.fromCol} -> ${move.toRow},${move.toCol}');

    setState(() {
    // This ensures CapturedPiecesWidget rebuilds when pieces are captured
    // The chess board handles its own updates separately
    });

    if (!_gameStarted) {
      setState(() {
        _gameStarted = true;
      });
    }

    _playMoveSound(move);
    
    if (move.capturedPiece != null) {
      VibrationService.medium();
    } else {
      VibrationService.light();
    }

    _autoSaveGame();

    if (_engine.isGameOver && !_gameOverDetected) {
      _gameOverDetected = true;
      GameTimerService.pause();
      
      // NEW: Pause ad timer when game ends
      AdTimerService.pauseAdTimer();
      
      print('🏁 Game over detected, waiting for visualization...');
      
      Future.delayed(const Duration(milliseconds: 3200), () {
        if (mounted && !_isGameOverDialogShowing) {
          _showGameOverDialog();
        }
      });
    } else if (_engine.isCheck) {
      VibrationService.heavy();
    }
  }

  void _playMoveSound(ChessMove move) {
    try {
      if (_engine.isGameOver) {
        if (_engine.gameState == GameState.checkmate) {
          SoundService.playCheckmate();
        } else {
          SoundService.playGameEnd();
        }
      } else if (_engine.isCheck) {
        SoundService.playCheck();
      } else if (move.isCastling) {
        SoundService.playCastling();
      } else if (move.capturedPiece != null) {
        SoundService.playCapture();
      } else {
        SoundService.playMove();
      }
    } catch (e) {
      print('❌ Error playing move sound: $e');
      SoundService.playButton();
    }
  }

  void _autoSaveGame() {
    if (_gameStarted && !_engine.isGameOver) {
      ChessSaveService.autoSave(
        engine: _engine,
        difficulty: _engine.difficulty,
        isPlayerWhite: _isPlayerWhite,
        gameTime: GameTimerService.getCurrentTime(),
      );
    }
  }

  void _showGameOverDialog() {
    if (_isGameOverDialogShowing) {
      print('⚠️ Game over dialog already showing, skipping...');
      return;
    }
    
    setState(() {
      _isGameOverDialogShowing = true;
    });
    
    print('🎭 Showing game over dialog');
    
    // NEW: Show ad when game finishes
    _showGameFinishAd();
    
    String title;
    String message;
    Color color;
    IconData icon;

    switch (_engine.gameState) {
      case GameState.checkmate:
        final winner = _engine.winner;
        final playerWon = (winner == PieceColor.white && _isPlayerWhite) ||
                         (winner == PieceColor.black && !_isPlayerWhite);
        title = playerWon ? 'Congratulations!' : 'Game Over';
        message = playerWon
            ? 'You won by checkmate!'
            : 'You lost by checkmate.';
        color = playerWon ? Colors.green : Colors.red;
        icon = playerWon ? Icons.emoji_events : Icons.sentiment_dissatisfied;
        
        if (playerWon) {
          VibrationService.buttonPressed();
        } else {
          VibrationService.heavy();
        }
        break;
      case GameState.stalemate:
        title = 'Stalemate';
        message = 'The game ended in a draw.\nNo legal moves available.';
        color = Colors.orange;
        icon = Icons.handshake;
        VibrationService.medium();
        break;
      case GameState.draw:
        title = 'Draw';
        message = 'The game ended in a draw.';
        color = Colors.blue;
        icon = Icons.handshake;
        VibrationService.medium();
        break;
      default:
        setState(() {
          _isGameOverDialogShowing = false;
          _gameOverDetected = false;
        });
        return;
    }

    ChessSaveService.deleteSavedGame();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: color, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Game Statistics',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Total Moves:', '${_engine.moveHistory.length}'),
                    _buildStatRow('Game Time:', GameTimerService.formatTime(GameTimerService.getCurrentTime())),
                    _buildStatRow('Difficulty:', _getDifficultyName(_engine.difficulty)),
                    _buildStatRow('Played as:', _isPlayerWhite ? 'White' : 'Black'),
                    if (_engine.gameState == GameState.checkmate)
                      _buildStatRow('Winner:', _engine.winner == PieceColor.white ? 'White' : 'Black'),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getGameTip(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.playButton();
              VibrationService.buttonPressed();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, size: 18),
                const SizedBox(width: 4),
                Text('Home'),
              ],
            ),
          ),
          
          ElevatedButton(
            onPressed: () {
              SoundService.playButton();
              VibrationService.buttonPressed();
              Navigator.pop(context);
              _restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 18),
                const SizedBox(width: 4),
                Text('Restart'),
              ],
            ),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isGameOverDialogShowing = false;
          _gameOverDetected = false;
        });
      }
    });
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getGameTip() {
    switch (_engine.gameState) {
      case GameState.checkmate:
        final playerWon = (_engine.winner == PieceColor.white && _isPlayerWhite) ||
                         (_engine.winner == PieceColor.black && !_isPlayerWhite);
        if (playerWon) {
          return 'Great job! Try a harder difficulty for more challenge.';
        } else {
          return 'Analyze the game to see how you could have avoided checkmate.';
        }
      case GameState.stalemate:
        return 'Stalemate happens when the king has no legal moves but isn\'t in check.';
      case GameState.draw:
        return 'Draws can result from insufficient material or repetition.';
      default:
        return 'Keep practicing to improve your chess skills!';
    }
  }

  void _restartGame() {
    setState(() {
      _gameStarted = false;
      _isColorSelected = false;
      _gameKey++;
      _isGameOverDialogShowing = false;
      _gameOverDetected = false;
    });
    
    GameTimerService.stop();
    _engine = ChessEngine(difficulty: _difficulty);
    ChessSaveService.deleteSavedGame();
    SoundService.playGameStart();
    
    // NEW: Resume ad timer and show transition ad for restart
    if (AdHelper.shouldShowAds()) {
      AdTimerService.startAdTimer();
      _showGameTransitionAd();
    }
    
    print('🔄 Game restarted with difficulty: $_difficulty');
  }

  String _getDifficultyName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Easy';
      case Difficulty.intermediate:
        return 'Medium';
      case Difficulty.advanced:
        return 'Hard';
    }
  }

  Widget _buildColorSelectionWidget() {
    return Container(
      height: MediaQuery.of(context).size.height - 
            (AppBar().preferredSize.height + MediaQuery.of(context).padding.top + 60),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_esports, 
                size: 100, 
                color: Colors.brown[600]
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose Your Side',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Play as White or Black against the AI.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildColorButton(
                context,
                'Play as White',
                Colors.white,
                () => _createNewGame(isPlayerWhite: true),
              ),
              const SizedBox(height: 20),
              _buildColorButton(
                context,
                'Play as Black',
                Colors.black,
                () => _createNewGame(isPlayerWhite: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorButton(BuildContext context, String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: () {
          SoundService.playButton();
          VibrationService.buttonPressed();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color == Colors.white ? Colors.white : Colors.black,
          foregroundColor: color == Colors.white ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 4,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_gameStarted && !_engine.isGameOver) {
          GameTimerService.pause();
        }
        // NEW: Pause ad timer when leaving screen
        AdTimerService.pauseAdTimer();
        _autoSaveGame();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Chess - ${_getDifficultyName(_difficulty)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.brown[600],
          foregroundColor: Colors.white,
          elevation: 0,
          // NEW: Debug action to show ad timer status and test ads
          actions: [
            if (kDebugMode)
              PopupMenuButton<String>(
                icon: Icon(Icons.bug_report),
                onSelected: (value) {
                  switch (value) {
                    case 'status':
                      AdTimerService.debugTimerStatus();
                      AdHelper.debugAdStatus();
                      break;
                    case 'timer_ad':
                      AdTimerService.debugTriggerAd();
                      break;
                    case 'finish_ad':
                      AdTimerService.debugTriggerGameFinishAd();
                      break;
                    case 'transition_ad':
                      AdTimerService.debugTriggerGameTransitionAd();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 20),
                        SizedBox(width: 8),
                        Text('Debug Status'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'timer_ad',
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 20),
                        SizedBox(width: 8),
                        Text('Test Timer Ad'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'finish_ad',
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 20),
                        SizedBox(width: 8),
                        Text('Test Finish Ad'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'transition_ad',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Test Transition Ad'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SafeArea(
                  child: _isColorSelected ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ChessGameInfoHeader(
                              difficulty: _getDifficultyName(_engine.difficulty),
                              initialTime: _initialGameTime ?? 0,
                            ),
                            
                            const SizedBox(height: 16),

                            CapturedPiecesWidget(
                              engine: _engine,
                              showWhiteCaptured: _isPlayerWhite,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            ChessBoardWidget(
                              key: ValueKey(_gameKey),
                              engine: _engine,
                              onMoveMade: _onMoveMade,
                              isPlayerWhite: _isPlayerWhite,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            CapturedPiecesWidget(
                              engine: _engine,
                              showWhiteCaptured: !_isPlayerWhite,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isPlayerWhite ? Icons.circle_outlined : Icons.circle,
                                    color: _isPlayerWhite ? Colors.grey[300] : Colors.grey[800],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Playing as: ${_isPlayerWhite ? 'White' : 'Black'}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (_adsRemoved)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ad-Free Experience',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // NEW: Debug info for development showing all ad types
                            if (kDebugMode) ...[
                              if (AdTimerService.isTimerActive)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timer, color: Colors.orange.shade700, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ad Timer Active (7min)',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.ads_click, color: Colors.purple.shade700, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ad Types Active',
                                          style: TextStyle(
                                            color: Colors.purple.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '🕐 Timer • 🏁 Game Finish • 🎮 Transitions',
                                      style: TextStyle(
                                        color: Colors.purple.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              if (AdHelper.shouldShowAds())
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ads support free gameplay',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            
                            if (AdHelper.canShowBannerAd()) 
                              const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ],
                  ) : _buildColorSelectionWidget(),
                ),
              ),
            ),
            
            BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}