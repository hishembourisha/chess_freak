// lib/screens/chess_game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/chess_engine.dart';
import '../services/stockfish_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/captured_pieces_widget.dart';
import '../services/chess_save_service.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../widgets/chess_game_info_widget.dart';
import '../helpers/ad_helper.dart';
import '../services/game_timer_service.dart';
import '../services/ad_timer_service.dart';
import '../services/ads_service.dart';
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
  
  // NEW: State variable to manage initialization state
  bool _isInitializing = true;
  
  // Game over dialog management
  bool _isGameOverDialogShowing = false;
  bool _gameOverDetected = false;
  
  // STOCKFISH: Pure Stockfish integration - no heuristic AI
  final StockfishService _stockfish = StockfishService();
  bool _aiThinking = false;

  // FIXED: Convert difficulty to AI level with stronger settings
  AiLevel _aiLevelFromDifficulty(Difficulty d) {
    switch (d) {
      case Difficulty.beginner: return AiLevel.easy;
      case Difficulty.intermediate: return AiLevel.medium;
      case Difficulty.advanced: return AiLevel.hard;
      case Difficulty.grandmaster: return AiLevel.grandmaster;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize with safe defaults
    _isPlayerWhite = true;
    _engine = ChessEngine(difficulty: _difficulty);
    
    _loadAdStatus();
    _ensureBackgroundMusicPlaying();
    _initializeAds();
  }

  @override
  void dispose() {
    GameTimerService.stop();
    AdTimerService.stopAdTimer();
    
    // CRITICAL FIX: Ensure Stockfish is properly disposed
    _disposeStockfish();
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // CRITICAL FIX: Separate method for Stockfish disposal
  Future<void> _disposeStockfish() async {
    try {
      await _stockfish.dispose();
      print('Stockfish disposed in game screen dispose');
    } catch (e) {
      print('Error disposing Stockfish: $e');
    }
  }

  Future<void> _initializeAds() async {
    try {
      await AdHelper.initialize();
      await AdsService.initialize();
      
      if (AdHelper.shouldShowAds()) {
        AdTimerService.startAdTimer();
        print('Ad timer started for chess game');
      } else {
        print('Ad timer not started - user has Remove Ads');
      }
      
      AdHelper.debugAdStatus();
      AdTimerService.debugTimerStatus();
    } catch (e) {
      print('Error initializing ads: $e');
    }
  }

  Future<void> _ensureBackgroundMusicPlaying() async {
    try {
      if (SoundService.isMusicEnabled && !SoundService.isMusicPlaying) {
        print('Starting background music on chess game screen');
        await SoundService.startBackgroundMusic();
      }
    } catch (e) {
      print('Error starting background music: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only run this once to prevent state issues on resume
    if (_isInitializing) {
      _processNavigationArguments();
    }
  }
  
  // NEW: Refactor argument processing into a separate method
  void _processNavigationArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      _difficulty = args['difficulty'] ?? Difficulty.beginner;
      _savedGameData = args['savedGameData'];
      _initialGameTime = _savedGameData?['gameTime'] as int?;
      
      if (_savedGameData != null) {
        print('Resuming game with difficulty: $_difficulty');
        _resumeGameFromData();
      } else {
        print('Starting new game with difficulty: $_difficulty');
        _isColorSelected = false;
        // The UI will show the color selection, and the game will start from there
      }
    } else {
      // Default to showing color selection if no arguments provided
      _isColorSelected = false;
    }

    setState(() {
      _isInitializing = false;
    });
  }

  void _resumeGameFromData() {
    try {
      final savedEngine = ChessSaveService.restoreGameState(_savedGameData!);
      if (savedEngine != null) {
        _engine = savedEngine;
        _isPlayerWhite = _savedGameData!['isPlayerWhite'] ?? true;
        _gameStarted = true;
        _isColorSelected = true;
        
        print('Successfully resumed chess game');
        print('Playing as: ${_isPlayerWhite ? 'White' : 'Black'}');
        
        // CRITICAL FIX: Always initialize Stockfish fresh for resumed games
        _initializeStockfishForNewGame().then((_) {
          // Only check for AI turn after Stockfish is fully ready
          final isAITurn = (_isPlayerWhite && _engine.currentPlayer == PieceColor.black) ||
                          (!_isPlayerWhite && _engine.currentPlayer == PieceColor.white);

          if (isAITurn) {
            print('Resuming game on AI turn. Triggering AI move...');
            // Longer delay for resumed games to ensure everything is stable
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted && !_engine.isGameOver) {
                _playAIMoveWithStockfish();
              }
            });
          }
        }).catchError((error) {
          print('Error initializing Stockfish for resumed game: $error');
          // If Stockfish initialization fails, still allow the game to continue
          // The player can make moves, but AI won't work until manual restart
        });

      } else {
        print('Failed to restore saved game, falling back to new game');
        _isColorSelected = false;
      }
    } catch (e) {
      print('Error resuming game: $e');
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
        
        // REFINED: Check ad timer status on resume
        if (AdHelper.shouldShowAds() && !AdTimerService.isTimerActive) {
          AdTimerService.startAdTimer();
          print('Ad timer resumed after app resume');
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
        
        if (_adsRemoved && AdTimerService.isTimerActive) {
          AdTimerService.stopAdTimer();
          print('Ad timer stopped - user now has Remove Ads');
        } else if (!_adsRemoved && !AdTimerService.isTimerActive) {
          AdTimerService.startAdTimer();
          print('Ad timer started - user is now free');
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
      _aiThinking = false; // STOCKFISH: Reset AI thinking state
    });
    
    _engine = ChessEngine(difficulty: _difficulty);
    GameTimerService.stop();
    
    // CRITICAL FIX: Ensure clean Stockfish initialization for new games
    _initializeStockfishForNewGame().then((_) {
      // Only proceed after Stockfish is fully initialized
      if (mounted) {
        SoundService.playGameStart();
        _showGameTransitionAd();
        
        if (!_isPlayerWhite) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _gameStarted = true;
              });
              // STOCKFISH: If player is black, AI (white) moves first
              _playAIMoveWithStockfish();
            }
          });
        } else {
          // For white player, just set game as started
          setState(() {
            _gameStarted = true;
          });
        }
      }
    });
  }

  // CRITICAL FIX: New method for clean Stockfish initialization
  Future<void> _initializeStockfishForNewGame() async {
    try {
      print('Initializing Stockfish for new game...');
      
      // Dispose any existing instance
      await _stockfish.dispose();
      
      // Small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Initialize fresh instance
      await _stockfish.init(level: _aiLevelFromDifficulty(_difficulty));
      await _stockfish.newGame();
      
      print('Stockfish initialized for difficulty: $_difficulty');
    } catch (e) {
      print('Error initializing Stockfish: $e');
    }
  }

  void _showGameFinishAd() {
    AdTimerService.showGameFinishAd();
  }

  void _showGameTransitionAd() {
    AdTimerService.showGameTransitionAd();
  }

  void _onMoveMade(ChessMove move) {
    print('Move made: ${move.fromRow},${move.fromCol} -> ${move.toRow},${move.toCol}');

    setState(() {
      // This ensures CapturedPiecesWidget rebuilds when pieces are captured
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
      AdTimerService.pauseAdTimer();
      
      print('Game over detected, waiting for visualization...');
      
      Future.delayed(const Duration(milliseconds: 3200), () {
        if (mounted && !_isGameOverDialogShowing) {
          _showGameOverDialog();
        }
      });
    } else if (_engine.isCheck) {
      VibrationService.heavy();
    }

    // STOCKFISH: After the human move, let Stockfish reply if game continues
    if (!_engine.isGameOver && !_aiThinking) {
      _playAIMoveWithStockfish();
    }
  }

  // STOCKFISH: Pure Stockfish AI move logic - with enhanced error handling for resume
  Future<void> _playAIMoveWithStockfish() async {
    if (_aiThinking || _engine.isGameOver) return;
    
    // Only AI should move when it's the AI's turn
    final isAITurn = (_isPlayerWhite && _engine.currentPlayer == PieceColor.black) ||
                      (!_isPlayerWhite && _engine.currentPlayer == PieceColor.white);
    
    if (!isAITurn) return;
    
    setState(() {
      _aiThinking = true;
    });
    
    try {
      // CRITICAL FIX: Ensure Stockfish is ready before making moves
      if (!_stockfish.isReady) {
        print('Stockfish not ready, reinitializing...');
        await _initializeStockfishForNewGame();
        
        // Additional safety check after reinitialization
        if (!_stockfish.isReady) {
          print('Stockfish still not ready after reinitialization');
          setState(() {
            _aiThinking = false;
          });
          return;
        }
      }
      
      print('AI thinking...');
      final fen = _engine.toFEN();
      print('Current FEN: $fen');
      
      // CRITICAL FIX: Add timeout protection for long-running operations
      Future<String> moveRequest = _stockfish.bestMoveForFen(fen);
      
      // Additional timeout wrapper for resume crashes
      String uci = await moveRequest.timeout(
        Duration(seconds: _difficulty == Difficulty.grandmaster ? 25 : 15),
        onTimeout: () {
          print('AI move request timed out, stopping AI thinking');
          throw TimeoutException('Stockfish move request timed out', Duration(seconds: 25));
        },
      );
      
      print('Stockfish suggests: $uci');
      
      // SAFETY CHECK: Validate UCI move format
      if (uci == 'none' || uci.length < 4) {
        print('Invalid UCI move received: $uci');
        setState(() {
          _aiThinking = false;
        });
        return;
      }
      
      final ok = _engine.applyUCIMove(uci);
      if (ok) {
        print('Stockfish move applied successfully');
        setState(() {
          _gameKey++; // This will force the ChessBoardWidget to rebuild completely
        });
        _autoSaveGame();
        
        // Play sound for AI move
        final lastMove = _engine.moveHistory.isNotEmpty ? _engine.moveHistory.last : null;
        if (lastMove != null) {
          _playMoveSound(lastMove);
        }
        
        // Check for vibration
        if (_engine.isCheck) {
          VibrationService.heavy();
        } else if (lastMove?.capturedPiece != null) {
          VibrationService.medium();
        } else {
          VibrationService.light();
        }
        
        // Check if game is over after AI move
        if (_engine.isGameOver && !_gameOverDetected) {
          _gameOverDetected = true;
          GameTimerService.pause();
          AdTimerService.pauseAdTimer();
          
          Future.delayed(const Duration(milliseconds: 4500), () {
            if (mounted && !_isGameOverDialogShowing) {
              _showGameOverDialog();
            }
          });
        }
      } else {
        print('Failed to apply Stockfish move: $uci');
        print('No fallback AI - pure Stockfish implementation');
      }
    } on TimeoutException catch (e) {
      print('Stockfish timeout exception: $e');
      // For timeouts, just stop thinking without crashing
    } catch (e) {
      if (kDebugMode) print('Stockfish error: $e');
      print('Stockfish failed, no fallback - pure implementation');
      
      // CRITICAL FIX: For resume crashes, try to reinitialize Stockfish
      if (e.toString().contains('timeout') || e.toString().contains('disposed')) {
        print('Attempting to recover from Stockfish error...');
        try {
          await _initializeStockfishForNewGame();
          print('Stockfish recovery successful');
        } catch (recoveryError) {
          print('Stockfish recovery failed: $recoveryError');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _aiThinking = false;
        });
      }
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
      print('Error playing move sound: $e');
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
      print('Game over dialog already showing, skipping...');
      return;
    }
    
    setState(() {
      _isGameOverDialogShowing = true;
    });
    
    print('Showing game over dialog');
    
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
            ? 'You defeated Stockfish!'
            : 'Stockfish checkmated you.';
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
                    _buildStatRow('AI Engine:', 'Stockfish'), // STOCKFISH: Show AI engine
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
          return 'Excellent! You defeated Stockfish at ${_getDifficultyName(_difficulty)} level.';
        } else {
          return 'Stockfish is a world-class engine. Study your games to improve!';
        }
      case GameState.stalemate:
        return 'Stalemate happens when the king has no legal moves but isn\'t in check.';
      case GameState.draw:
        return 'Draws can result from insufficient material or repetition.';
      default:
        return 'Keep practicing against Stockfish to improve your chess skills!';
    }
  }

  void _restartGame() {
    setState(() {
      _gameStarted = false;
      _isColorSelected = false;
      _gameKey++;
      _isGameOverDialogShowing = false;
      _gameOverDetected = false;
      _aiThinking = false; // STOCKFISH: Reset AI thinking state
    });
    
    GameTimerService.stop();
    _engine = ChessEngine(difficulty: _difficulty);
    ChessSaveService.deleteSavedGame();
    
    // CRITICAL FIX: Don't initialize Stockfish here, let _createNewGame handle it
    // _initializeStockfishForNewGame(); // REMOVED
    
    SoundService.playGameStart();
    
    if (AdHelper.shouldShowAds()) {
      AdTimerService.startAdTimer();
      _showGameTransitionAd();
    }
    
    print('Game restarted with Stockfish at difficulty: $_difficulty');
  }

  String _getDifficultyName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Easy';
      case Difficulty.intermediate:
        return 'Medium';
      case Difficulty.advanced:
        return 'Hard';
      case Difficulty.grandmaster:
        return 'Grandmaster';
    }
  }

  Widget _buildColorSelectionWidget() {
    return SizedBox(
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
                'Play against AI',
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
        AdTimerService.pauseAdTimer();
        _autoSaveGame();
        
        // CRITICAL FIX: Dispose Stockfish when leaving the screen
        await _disposeStockfish();
        print('Stockfish disposed when leaving game screen');
        
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
          actions: [
            // STOCKFISH: Show AI thinking indicator
            if (_aiThinking)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Thinking...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: SafeArea(
                        child: _isColorSelected
                            ? Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        ChessGameInfoHeader(
                                          difficulty: _getDifficultyName(_engine.difficulty),
                                          onRestartGame: _restartGame,
                                          initialTime: _initialGameTime ?? 0,
                                        ),
                                        
                                        const SizedBox(height: 16),

                                        CapturedPiecesWidget(
                                          engine: _engine,
                                          showWhiteCaptured: _isPlayerWhite,
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // FIXED: Pass useStockfish flag to disable heuristic AI in board
                                        ChessBoardWidget(
                                          key: ValueKey(_gameKey),
                                          engine: _engine,
                                          onMoveMade: _onMoveMade,
                                          isPlayerWhite: _isPlayerWhite,
                                          useStockfish: true, // STOCKFISH: Pure Stockfish mode
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
                              )
                            : _buildColorSelectionWidget(),
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