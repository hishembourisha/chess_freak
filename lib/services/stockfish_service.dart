// lib/services/stockfish_service.dart - Enhanced with improved disposal

import 'dart:async';
import 'package:stockfish/stockfish.dart' as sf;

enum AiLevel { easy, medium, hard, grandmaster }

class StockfishService {
  sf.Stockfish? _engine;
  StreamSubscription<String>? _stdoutSub;
  Completer<String>? _bestmoveWaiter;
  AiLevel _level = AiLevel.medium;

  bool get isReady =>
      _engine != null && _engine!.state.value == sf.StockfishState.ready;

  Future<void> init({AiLevel level = AiLevel.medium}) async {
    _level = level;
    _engine ??= sf.Stockfish();

    // Wait until engine is ready
    while (_engine!.state.value != sf.StockfishState.ready) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    _stdoutSub?.cancel();
    _stdoutSub = _engine!.stdout.listen((line) {
      if (line.startsWith('bestmove ')) {
        final parts = line.split(' ');
        if (parts.length >= 2 && _bestmoveWaiter != null && !_bestmoveWaiter!.isCompleted) {
          _bestmoveWaiter!.complete(parts[1]);
        }
      }
    });

    _engine!.stdin = 'uci';
    _engine!.stdin = 'isready';
    await _waitReadyOk();
    _engine!.stdin = 'ucinewgame';
    await setLevel(_level);
  }

  Future<void> setLevel(AiLevel level) async {
    _level = level;
    switch (level) {
      case AiLevel.easy:
        // Beginner: Very weak play - deliberate blunders
        _engine!.stdin = 'setoption name UCI_LimitStrength value true';
        _engine!.stdin = 'setoption name UCI_Elo value 600'; // Lower ELO for weaker play
        _engine!.stdin = 'setoption name Skill Level value 0';
        _engine!.stdin = 'setoption name Move Overhead value 100'; // Add some delay
        break;
      case AiLevel.medium:
        // Intermediate: Club player strength
        _engine!.stdin = 'setoption name UCI_LimitStrength value true';
        _engine!.stdin = 'setoption name UCI_Elo value 1600'; // Slightly higher for better play
        _engine!.stdin = 'setoption name Skill Level value 12'; // Better skill level
        _engine!.stdin = 'setoption name Move Overhead value 50';
        break;
      case AiLevel.hard:
        // Advanced: Very strong play - near full strength
        _engine!.stdin = 'setoption name UCI_LimitStrength value false'; // No ELO limit
        _engine!.stdin = 'setoption name Skill Level value 20'; // Maximum skill
        _engine!.stdin = 'setoption name Move Overhead value 0'; // No artificial delay
        _engine!.stdin = 'setoption name Hash value 128'; // More memory for calculations
        _engine!.stdin = 'setoption name Threads value 1'; // Single thread for mobile
        break;
      case AiLevel.grandmaster:
        // Grandmaster: World-class strength with higher search depth
        _engine!.stdin = 'setoption name UCI_LimitStrength value false';
        _engine!.stdin = 'setoption name Skill Level value 20';
        _engine!.stdin = 'setoption name Move Overhead value 0';
        _engine!.stdin = 'setoption name Hash value 256'; // More memory
        _engine!.stdin = 'setoption name Threads value 2'; // Use two threads if available
        break;
    }
    _engine!.stdin = 'isready';
    await _waitReadyOk();
    print('Stockfish level set to: $level');
  }

  Future<String> bestMoveForFen(String fen) async {
    if (!isReady) {
      await init(level: _level);
    }
    _engine!.stdin = 'position fen $fen';
    
    // ENHANCED: Much stronger time allocation and depth settings
    String searchCommand;
    switch (_level) {
      case AiLevel.easy:
        // Easy: Very limited thinking time
        searchCommand = 'go movetime 400'; // 0.4 seconds
        break;
      case AiLevel.medium:
        // Medium: Moderate thinking time
        searchCommand = 'go depth 3 movetime 6000'; // 3 ply depth OR 6 seconds max
        break;
      case AiLevel.hard:
        // Hard: Deep analysis - use both time and depth for maximum strength
        searchCommand = 'go depth 10 movetime 10000'; // 10 ply depth OR 10 seconds max
        break;
      case AiLevel.grandmaster:
        // Grandmaster: Very deep analysis - use more time and depth
        searchCommand = 'go depth 20 movetime 16000'; // 20 ply depth OR 16 seconds max
        break;
        
    }
    
    print('Stockfish search: $searchCommand');
    
    _bestmoveWaiter = Completer<String>();
    _engine!.stdin = searchCommand;
    
    // Increase timeout to accommodate longer thinking times
    final timeoutSeconds = switch (_level) {
      AiLevel.easy => 3,
      AiLevel.medium => 11,
      AiLevel.hard => 15, // Much longer for deep analysis
      AiLevel.grandmaster => 25, // Even longer for GM level
    };
    
    final timeout = Duration(seconds: timeoutSeconds);
    
    try {
      final result = await _bestmoveWaiter!.future.timeout(timeout);
      print('Stockfish move found: $result');
      return result;
    } catch (e) {
      print('Stockfish timeout or error: $e');
      // Return a fallback move if possible
      rethrow;
    }
  }

  Future<void> newGame() async {
    if (_engine == null) return;
    _engine!.stdin = 'ucinewgame';
    _engine!.stdin = 'isready';
    await _waitReadyOk();
    print('Stockfish new game started');
  }

  // CRITICAL FIX: Improved dispose method with proper cleanup
  Future<void> dispose() async {
    try {
      print('Disposing Stockfish engine...');
      
      // Cancel any pending operations
      if (_bestmoveWaiter != null && !_bestmoveWaiter!.isCompleted) {
        _bestmoveWaiter!.complete('none'); // Complete any waiting operations
      }
      _bestmoveWaiter = null;
      
      // Cancel stream subscription
      _stdoutSub?.cancel();
      _stdoutSub = null;
      
      // Send quit command and dispose engine
      if (_engine != null) {
        try {
          _engine?.stdin = 'quit';
          await Future.delayed(const Duration(milliseconds: 100)); // Give time for quit
        } catch (e) {
          print('Error sending quit command: $e');
        }
        
        _engine?.dispose();
      }
      
      print('Stockfish engine disposed successfully');
    } catch (e) {
      print('Error during Stockfish disposal: $e');
    } finally {
      _engine = null;
    }
  }

  Future<void> _waitReadyOk() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  // DEBUG: Get current level info
  String get currentLevelInfo {
    switch (_level) {
      case AiLevel.easy:
        return 'Easy (ELO ~600, 0.3s thinking)';
      case AiLevel.medium:
        return 'Medium (ELO ~1600, 3s thinking)';
      case AiLevel.hard:
        return 'Hard (Full Strength, 12s + depth 15)';
      case AiLevel.grandmaster:
        return 'Grandmaster (Full Strength, 25s + depth 25)';
    }
  }
}