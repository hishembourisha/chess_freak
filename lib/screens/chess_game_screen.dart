// lib/screens/chess_game_screen.dart - Fixed sound issues
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/chess_engine.dart';
import '../widgets/chess_board.dart';
import '../widgets/captured_pieces_widget.dart';
import '../services/chess_save_service.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../widgets/chess_game_info_widget.dart';
import '../services/ads_service.dart';
import '../helpers/ad_helper.dart';
import '../services/game_timer_service.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({Key? key}) : super(key: key);

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
  int _gameKey = 0; // For forcing widget rebuilds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize with safe defaults
    _isPlayerWhite = true;
    _engine = ChessEngine(difficulty: _difficulty);
    
    _loadAdStatus();
    
    // FIXED: Ensure background music starts when game screen loads
    _ensureBackgroundMusicPlaying();
  }

  @override
  void dispose() {
    GameTimerService.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FIXED: Method to ensure background music is playing
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
    
    // INSPIRED BY SUDOKU: Handle navigation arguments here
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      setState(() {
        _difficulty = args['difficulty'] ?? Difficulty.beginner;
        _savedGameData = args['savedGameData'];
        _initialGameTime = _savedGameData?['gameTime'] as int?;
        
        if (_savedGameData != null) {
          // RESUME GAME
          print('🔄 Resuming game with difficulty: $_difficulty');
          _resumeGameFromData();
        } else {
          // NEW GAME
          print('🎮 Starting new game with difficulty: $_difficulty');
          _isColorSelected = false; // Show color selection
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
        _isColorSelected = true; // Skip color selection for resumed games
        
        print('✅ Successfully resumed chess game');
        print('🎯 Playing as: ${_isPlayerWhite ? 'White' : 'Black'}');
      } else {
        print('❌ Failed to restore saved game, falling back to new game');
        _isColorSelected = false; // Show color selection
      }
    } catch (e) {
      print('❌ Error resuming game: $e');
      _isColorSelected = false; // Show color selection as fallback
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
        // FIXED: Pause background music when app is paused
        SoundService.pauseBackgroundMusic();
        _autoSaveGame();
        break;
      case AppLifecycleState.resumed:
        if (_gameStarted && !_engine.isGameOver) {
          GameTimerService.resume();
        }
        // FIXED: Resume background music when app is resumed
        _ensureBackgroundMusicPlaying();
        _loadAdStatus();
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
      _gameKey++; // Force rebuild
    });
    
    _engine = ChessEngine(difficulty: _difficulty);
    GameTimerService.stop(); // Clean slate
    
    // FIXED: Play game start sound
    SoundService.playGameStart();
    
    print('🎮 Created new chess game');
    print('🎯 Player is playing as: ${_isPlayerWhite ? 'White' : 'Black'}');
    
    // If player is Black, AI should move first
    if (!_isPlayerWhite) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _gameStarted = true;
          });
        }
      });
    }
  }

  // FIXED: Improved move sound handling
  void _onMoveMade(ChessMove move) {
    // 🐛 ADD THIS - Forces UI to rebuild and show captured pieces
    setState(() {
      // This rebuilds the entire widget tree, including CapturedPiecesWidget
    });

    if (!_gameStarted) {
      setState(() {
        _gameStarted = true;
      });
    }

    // FIXED: Play appropriate sounds based on move type
    _playMoveSound(move);
    
    // FIXED: Appropriate vibration based on move type
    if (move.capturedPiece != null) {
      VibrationService.medium();
    } else {
      VibrationService.light();
    }

    _autoSaveGame();

    if (_engine.isGameOver) {
      GameTimerService.pause();
      _showGameOverDialog();
    } else if (_engine.isCheck) {
      // Check sound is already played in _playMoveSound
      VibrationService.heavy();
    }
  }

  // FIXED: New method to play appropriate move sounds based on your actual ChessEngine
  void _playMoveSound(ChessMove move) {
    try {
      // Priority order for sounds (most important first)
      if (_engine.isGameOver) {
        if (_engine.gameState == GameState.checkmate) {
          SoundService.playCheckmate();
        } else {
          SoundService.playGameEnd(); // Stalemate/draw
        }
      } else if (_engine.isCheck) {
        SoundService.playCheck();
      } else if (move.isCastling) {
        // This property exists in your ChessMove class
        SoundService.playCastling();
      } else if (move.capturedPiece != null) {
        SoundService.playCapture();
      } else {
        SoundService.playMove();
      }
    } catch (e) {
      print('❌ Error playing move sound: $e');
      // Fallback to button sound
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
    String title;
    String message;
    Color color;

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
        
        // FIXED: Appropriate sounds are already played in _playMoveSound
        if (playerWon) {
          VibrationService.buttonPressed();
        } else {
          VibrationService.heavy();
        }
        break;
      case GameState.stalemate:
        title = 'Stalemate';
        message = 'The game ended in a draw.';
        color = Colors.grey;
        // Sound already played in _playMoveSound
        VibrationService.medium();
        break;
      case GameState.draw:
        title = 'Draw';
        message = 'The game ended in a draw.';
        color = Colors.blue;
        // Sound already played in _playMoveSound
        VibrationService.medium();
        break;
      default:
        return;
    }

    ChessSaveService.deleteSavedGame();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _engine.gameState == GameState.checkmate
                  ? Icons.emoji_events
                  : Icons.handshake,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Text('Game Statistics:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Total Moves: ${_engine.moveHistory.length}'),
            Text('Game Time: ${GameTimerService.formatTime(GameTimerService.getCurrentTime())}'),
            Text('Difficulty: ${_getDifficultyName(_engine.difficulty)}'),
            Text('Played as: ${_isPlayerWhite ? 'White' : 'Black'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.playButton(); // FIXED: Add button sound
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Home'),
          ),
        ],
      ),
    );
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

  Widget _buildBannerAdWidget() {
    final bannerAd = AdsService.bannerAd;
    
    if (bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: AdWidget(ad: bannerAd),
      );
    }
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: const Center(
        child: Text(
          'Ad Loading...',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildColorSelectionWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports, size: 100, color: Colors.brown[600]),
          const SizedBox(height: 24),
          const Text(
            'Choose Your Side',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play as White or Black against the AI.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
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
    );
  }

  Widget _buildColorButton(BuildContext context, String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: () {
          SoundService.playButton(); // FIXED: Add button sound
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
        _autoSaveGame();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Chess ${_getDifficultyName(_difficulty)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.brown[600],
          foregroundColor: Colors.white,
          elevation: 0,
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
                              //key: ValueKey(_gameKey), // Force rebuild on new games
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
                              key: ValueKey(_gameKey), // Force rebuild on new games
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
            
            if (AdHelper.canShowBannerAd()) _buildBannerAdWidget(),
          ],
        ),
      ),
    );
  }
}