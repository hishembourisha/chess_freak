// lib/widgets/sudoku_grid.dart - Complete version with Remove Ads fixes
import 'dart:async'; // ADD: For Timer
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sudoku_generator.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../services/ads_service.dart';
import '../services/ad_helper.dart'; // ADDED: For Remove Ads logic
import '../services/game_save_service.dart';
import '../services/game_timer_service.dart';
import 'sudoku_board.dart';
import 'number_pad.dart';
import 'game_info_header.dart';
import 'completion_dialog.dart';
import 'hint_dialog.dart';
import 'error_dialog.dart';
import 'package:flutter/foundation.dart';

class SudokuGrid extends StatefulWidget {
  final String difficulty;
  final List<List<int>>? initialPuzzle;
  final Function(bool)? onPuzzleComplete;
  final Map<String, dynamic>? savedGameData;
  final int? initialGameTime;
  final VoidCallback? onRestartGame;

  const SudokuGrid({
    super.key,
    this.difficulty = 'medium',
    this.initialPuzzle,
    this.onPuzzleComplete,
    this.savedGameData,
    this.initialGameTime,
    this.onRestartGame,
  });

  @override
  State<SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<SudokuGrid> with SingleTickerProviderStateMixin {
  late List<List<int>> _puzzle;
  late List<List<int>> _solution;
  late List<List<bool>> _isFixed;
  late List<List<bool>> _isError;
  late List<List<bool>> _isHint;
  late List<List<Set<int>>> _cornerNotes;
  
  int? _selectedRow;
  int? _selectedCol;
  bool _isPuzzleComplete = false;
  bool _showErrors = true;
  bool _noteMode = false;
  int _hintsUsed = 0;
  int _hintBalance = 0;
  
  // Error tracking system - FIXED: Dynamic based on Remove Ads
  int _errorCount = 0;
  final int _maxErrors = 3; // Base errors for free users
  bool _gameBlocked = false;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // FIXED: Add periodic save timer
  Timer? _autoSaveTimer;

  // ADDED: Get max errors based on Remove Ads status
  int get _maxErrorsForUser {
    return AdHelper.shouldShowAds() ? _maxErrors : (_maxErrors + 2); // 5 errors for paid users
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializePuzzle();
    _loadHintBalance();
    _initializeServices();
    _startPeriodicAutoSave(); // FIXED: Start periodic saving
  }

  @override
  void dispose() {
    // FIXED: Save current timer state when leaving the game
    if (!_isPuzzleComplete) {
      _autoSaveGame();
    }
    _autoSaveTimer?.cancel(); // FIXED: Cancel periodic save timer
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SudokuGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // FIXED: Detect difficulty change OR restart (when savedData becomes null)
    bool difficultyChanged = oldWidget.difficulty != widget.difficulty;
    bool isRestart = oldWidget.savedGameData != null && widget.savedGameData == null;
    
    if (difficultyChanged || isRestart) {
      if (kDebugMode) {
        if (difficultyChanged) {
          print('🔄 Difficulty changed from ${oldWidget.difficulty} to ${widget.difficulty}');
        } else {
          print('🔄 Restarting ${widget.difficulty} game');
        }
        print('🎯 Generating new ${widget.difficulty} puzzle...');
      }
      
      // Generate new puzzle with new difficulty
      _generateNewPuzzleForDifficulty();
    }
  }

  // FIXED: Generate new puzzle when difficulty changes
  void _generateNewPuzzleForDifficulty() {
    setState(() {
      // Reset all game state
      _selectedRow = null;
      _selectedCol = null;
      _isPuzzleComplete = false;
      _noteMode = false;
      _hintsUsed = 0;
      _errorCount = 0;
      _gameBlocked = false;
      
      // Generate new puzzle with the new difficulty
      if (kDebugMode) {
        print('🎯 Generating ${widget.difficulty} puzzle...');
        SudokuGenerator.resetMetrics();
      }
      
      _puzzle = SudokuGenerator.generatePuzzle(widget.difficulty);
      
      if (kDebugMode) {
        print('✅ New ${widget.difficulty} puzzle generated');
        print('📈 Metrics: ${SudokuGenerator.getMetrics()}');
      }
      
      // Generate new solution
      _solution = _puzzle.map((row) => List<int>.from(row)).toList();
      _solvePuzzle(_solution);
      
      // Reset all tracking arrays
      _isFixed = List.generate(9, (i) => List.generate(9, (j) => _puzzle[i][j] != 0));
      _isError = List.generate(9, (i) => List.filled(9, false));
      _isHint = List.generate(9, (i) => List.filled(9, false));
      _cornerNotes = List.generate(9, (i) => List.generate(9, (j) => <int>{}));
    });
    
    // Delete any saved game since we're starting new
    GameSaveService.deleteSavedGame();
    
    // Start fresh timer
    GameTimerService.stop();
    GameTimerService.start(onTimeUpdate: (seconds) {
      // Timer updates will be handled by GameInfoTop
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New ${widget.difficulty} puzzle generated!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void deactivate() {
    // FIXED: Save when widget becomes inactive (user navigates away)
    if (!_isPuzzleComplete) {
      _autoSaveGame();
      if (kDebugMode) {
        print('💾 Auto-saved game state when navigating away');
      }
    }
    super.deactivate();
  }

  // FIXED: Start periodic auto-save to capture timer progress
  void _startPeriodicAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isPuzzleComplete && mounted) {
        _autoSaveGame();
        if (kDebugMode) {
          print('💾 Periodic auto-save: ${GameTimerService.formatTime(GameTimerService.getCurrentTime())}');
        }
      }
    });
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    await SoundService.initialize();
    await VibrationService.initialize();
  }

  void _initializePuzzle() {
    if (widget.savedGameData != null) {
      // Load from saved game
      _loadFromSavedData(widget.savedGameData!);
    } else if (widget.initialPuzzle != null) {
      // Load from provided puzzle
      _puzzle = widget.initialPuzzle!.map((row) => List<int>.from(row)).toList();
      _generateSolutionAndInitialize();
    } else {
      // Generate new puzzle with enhanced generator
      if (kDebugMode) {
        print('🎯 Generating ${widget.difficulty} puzzle...');
        SudokuGenerator.resetMetrics();
      }
      
      _puzzle = SudokuGenerator.generatePuzzle(widget.difficulty);
      
      if (kDebugMode) {
        print('📊 Generation completed');
        print('📈 Metrics: ${SudokuGenerator.getMetrics()}');
        SudokuGenerator.debugPuzzle(_puzzle);
      }
      
      _generateSolutionAndInitialize();
    }
  }

  void _loadFromSavedData(Map<String, dynamic> savedData) {
    // Convert puzzle data with proper type casting
    _puzzle = (savedData['puzzle'] as List).map((row) => 
      (row as List).map((cell) => (cell as num).toInt()).toList()
    ).toList();
    
    _solution = (savedData['solution'] as List).map((row) => 
      (row as List).map((cell) => (cell as num).toInt()).toList()
    ).toList();
    
    _isFixed = (savedData['isFixed'] as List).map((row) => 
      (row as List).map((cell) => cell as bool).toList()
    ).toList();
    
    _isHint = (savedData['isHint'] as List).map((row) => 
      (row as List).map((cell) => cell as bool).toList()
    ).toList();
    
    // FIXED: Convert corner notes with proper Set reconstruction
    _cornerNotes = (savedData['cornerNotes'] as List).map((row) => 
      (row as List).map((cell) {
        if (cell is List) {
          // Convert List back to Set<int>
          return cell.map((note) => (note as num).toInt()).toSet();
        } else if (cell is Set) {
          // Already a Set, just ensure int type
          return cell.map((note) => (note as num).toInt()).toSet();
        } else {
          // Fallback: empty set
          return <int>{};
        }
      }).toList()
    ).toList();
    
    // Safe casting for primitive types with defaults
    _hintsUsed = (savedData['hintsUsed'] as int?) ?? 0;
    _errorCount = (savedData['errorCount'] as int?) ?? 0;
    _noteMode = (savedData['noteMode'] as bool?) ?? false;
    _selectedRow = savedData['selectedRow'] as int?;
    _selectedCol = savedData['selectedCol'] as int?;
    
    if (kDebugMode) {
      print('📂 Loaded saved game: ${savedData['difficulty']}');
      print('📊 Hints used: $_hintsUsed, Errors: $_errorCount');
      print('📝 Note mode: $_noteMode');
    }
    
    // Initialize error tracking using generator's validation
    _isError = List.generate(9, (i) => List.filled(9, false));
    if (_showErrors) {
      _updateErrorStates();
    }
  }

  void _generateSolutionAndInitialize() {
    // Generate solution using the same algorithm as generator
    _solution = _puzzle.map((row) => List<int>.from(row)).toList();
    _solvePuzzle(_solution);
    
    // Initialize tracking arrays
    _isFixed = List.generate(9, (i) => List.generate(9, (j) => _puzzle[i][j] != 0));
    _isError = List.generate(9, (i) => List.filled(9, false));
    _isHint = List.generate(9, (i) => List.filled(9, false));
    _cornerNotes = List.generate(9, (i) => List.generate(9, (j) => <int>{}));
  }

  Future<void> _loadHintBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hintBalance = prefs.getInt('hint_balance') ?? 3;
    });
  }

  // FIXED: Use exact same validation as generator
  bool _isValidMove(List<List<int>> grid, int row, int col, int num) {
    return SudokuGenerator.isValidMove(grid, row, col, num);
  }

  bool _solvePuzzle(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (_isValidMove(grid, row, col, num)) {
              grid[row][col] = num;
              if (_solvePuzzle(grid)) return true;
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  void _selectCell(int row, int col) {
    if (_isFixed[row][col] || _isPuzzleComplete || _gameBlocked) return;
    
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
    });
    
    SoundService.playSelect();
    VibrationService.cellSelected();
  }

  void _enterNumber(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    if (_isFixed[_selectedRow!][_selectedCol!]) return;
    if (_isPuzzleComplete || _gameBlocked) return;

    setState(() {
      if (_noteMode) {
        // Toggle notes
        if (_cornerNotes[_selectedRow!][_selectedCol!].contains(number)) {
          _cornerNotes[_selectedRow!][_selectedCol!].remove(number);
        } else {
          _cornerNotes[_selectedRow!][_selectedCol!].add(number);
        }
        SoundService.playToggle();
        VibrationService.modeToggle();
      } else {
        // Debug the placement before entering
        if (kDebugMode) {
          _debugCellValidation(_selectedRow!, _selectedCol!, number);
        }
        
        // Enter number
        _puzzle[_selectedRow!][_selectedCol!] = number;
        _cornerNotes[_selectedRow!][_selectedCol!].clear();
        _isHint[_selectedRow!][_selectedCol!] = false;
        
        if (_showErrors) {
          _updateErrorStates();
        }
        
        // Check if this move created an error
        bool isWrongMove = _isError[_selectedRow!][_selectedCol!];
        
        if (isWrongMove) {
          if (kDebugMode) {
            print('❌ Move marked as error at (${_selectedRow!}, ${_selectedCol!}) with number $number');
          }
          _handleError();
        } else {
          SoundService.playPlace();
          VibrationService.correctEntry();
        }
        
        _checkPuzzleCompletion();
      }
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    // Auto-save after each move
    _autoSaveGame();
  }

  // ENHANCED: Debug method for cell validation
  void _debugCellValidation(int row, int col, int num) {
    if (kDebugMode) {
      print('🔍 Debugging cell ($row, $col) with number $num');
      
      // Check using generator's validation
      List<List<int>> tempGrid = _puzzle.map((row) => List<int>.from(row)).toList();
      tempGrid[row][col] = 0; // Remove current value for testing
      
      bool isValid = SudokuGenerator.isValidMove(tempGrid, row, col, num);
      print('🔍 Generator validation result: $isValid');
      
      if (!isValid) {
        // Check what's causing the conflict
        print('🔍 Checking conflicts:');
        
        // Check row
        for (int i = 0; i < 9; i++) {
          if (i != col && _puzzle[row][i] == num) {
            print('   ❌ Row conflict at column $i');
          }
        }
        
        // Check column
        for (int i = 0; i < 9; i++) {
          if (i != row && _puzzle[i][col] == num) {
            print('   ❌ Column conflict at row $i');
          }
        }
        
        // Check box
        int boxRow = (row ~/ 3) * 3;
        int boxCol = (col ~/ 3) * 3;
        for (int i = boxRow; i < boxRow + 3; i++) {
          for (int j = boxCol; j < boxCol + 3; j++) {
            if ((i != row || j != col) && _puzzle[i][j] == num) {
              print('   ❌ Box conflict at ($i, $j)');
            }
          }
        }
      }
    }
  }

  // FIXED: Enhanced error state detection
  void _updateErrorStates() {
    // Reset all errors first
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        _isError[i][j] = false;
      }
    }

    // Check each filled cell for conflicts using generator validation
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (_puzzle[row][col] != 0) {
          // Create a temporary grid to test this cell
          List<List<int>> tempGrid = _puzzle.map((row) => List<int>.from(row)).toList();
          
          // Temporarily remove this cell's value
          int currentValue = tempGrid[row][col];
          tempGrid[row][col] = 0;
          
          // Check if placing the current value would be valid using generator logic
          if (!SudokuGenerator.isValidMove(tempGrid, row, col, currentValue)) {
            _isError[row][col] = true;
            if (kDebugMode) {
              print('❌ Error detected at ($row, $col) with value $currentValue');
            }
          }
        }
      }
    }
  }

  // Auto-save functionality with timer support
  Future<void> _autoSaveGame() async {
    if (_isPuzzleComplete) return; // Don't save completed games
    
    await GameSaveService.saveGame(
      difficulty: widget.difficulty,
      puzzle: _puzzle,
      solution: _solution,
      isFixed: _isFixed,
      isHint: _isHint,
      cornerNotes: _cornerNotes,
      hintsUsed: _hintsUsed,
      errorCount: _errorCount,
      noteMode: _noteMode,
      selectedRow: _selectedRow,
      selectedCol: _selectedCol,
      gameTime: GameTimerService.getCurrentTime(),
      timestamp: DateTime.now(),
    );
  }

  // FIXED: Handle error logic with Remove Ads support
  void _handleError() {
    _errorCount++;
    
    SoundService.playError();
    VibrationService.errorEntry();
    
    if (_errorCount >= _maxErrorsForUser) {
      // Block the game
      setState(() {
        _gameBlocked = true;
      });
      
      // Show error dialog
      _showErrorDialog();
    } else {
      // Show different messages based on Remove Ads status
      String message = AdHelper.shouldShowAds() 
          ? 'Error $_errorCount/$_maxErrors - Be careful!'
          : 'Error $_errorCount/$_maxErrorsForUser - Ad-free gaming!';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AdHelper.shouldShowAds() ? Colors.orange : Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // FIXED: Show error dialog with Remove Ads logic
  void _showErrorDialog() {
    // Check if ads are removed - if so, automatically reset errors
    if (!AdHelper.shouldShowAds()) {
      // User has purchased Remove Ads - automatically reset errors
      setState(() {
        _errorCount = 0;
        _gameBlocked = false;
      });
      
      // Show friendly message instead of ad prompt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Errors reset! Ad-free gaming activated.'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      SoundService.playButton();
      VibrationService.medium();
      return;
    }
    
    // Original ad-based error dialog for users who haven't purchased Remove Ads
    ErrorDialog.show(
      context,
      errorCount: _errorCount,
      onWatchAd: () {
        // Reset errors and unblock game
        setState(() {
          _errorCount = 0;
          _gameBlocked = false;
        });
      },
      onGameOver: () {
        // Return to home screen
        Navigator.of(context).pop();
      },
    );
  }

  void _clearCell() {
    if (_selectedRow == null || _selectedCol == null) return;
    if (_isFixed[_selectedRow!][_selectedCol!]) return;
    if (_isPuzzleComplete || _gameBlocked) return;

    setState(() {
      _puzzle[_selectedRow!][_selectedCol!] = 0;
      _cornerNotes[_selectedRow!][_selectedCol!].clear();
      _isError[_selectedRow!][_selectedCol!] = false;
      _isHint[_selectedRow!][_selectedCol!] = false;
    });

    SoundService.playButton();
    VibrationService.cellCleared();
  }

  void _toggleNoteMode() {
    if (_gameBlocked) return;
    
    setState(() {
      _noteMode = !_noteMode;
    });
    
    SoundService.playToggle();
    VibrationService.modeToggle();
  }

  void _checkPuzzleCompletion() {
    bool isComplete = true;
    bool hasErrors = false;

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_puzzle[i][j] == 0) {
          isComplete = false;
          break;
        }
        if (_isError[i][j]) {
          hasErrors = true;
        }
      }
      if (!isComplete) break;
    }

    if (isComplete && !hasErrors) {
      setState(() {
        _isPuzzleComplete = true;
      });
      
      SoundService.playComplete();
      VibrationService.puzzleComplete();
      
      // Delete saved game when completed
      GameSaveService.deleteSavedGame();
      
      // FIXED: Only call parent callback, don't show completion dialog here
      // The GameScreen will handle showing the replay dialog
      widget.onPuzzleComplete?.call(true);
      
      if (kDebugMode) {
        print('🎉 Puzzle completed! Notifying parent...');
      }
    }
  }

  Future<void> _useHint() async {
    if (_gameBlocked) return;
    
    if (_hintBalance <= 0) {
      HintDialog.show(context, onHintsEarned: (hints) {
        setState(() {
          _hintBalance += hints;
        });
      });
      return;
    }

    if (_selectedRow == null || _selectedCol == null) {
      VibrationService.errorEntry();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cell first')),
      );
      return;
    }

    if (_isFixed[_selectedRow!][_selectedCol!] || 
        _puzzle[_selectedRow!][_selectedCol!] != 0) {
      VibrationService.errorEntry();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cell is already filled')),
      );
      return;
    }

    // FIXED: Use the solution we already have instead of generator
    if (kDebugMode) {
      print('🔍 Using hint for cell (${_selectedRow!}, ${_selectedCol!})');
      print('🔍 Solution value: ${_solution[_selectedRow!][_selectedCol!]}');
    }

    // Use hint from our existing solution
    final hintValue = _solution[_selectedRow!][_selectedCol!];
    
    if (hintValue == 0) {
      VibrationService.errorEntry();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hint available for this cell')),
      );
      return;
    }

    // Use hint
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hint_balance', _hintBalance - 1);
    
    setState(() {
      _puzzle[_selectedRow!][_selectedCol!] = hintValue;
      _cornerNotes[_selectedRow!][_selectedCol!].clear();
      _isHint[_selectedRow!][_selectedCol!] = true;
      _hintBalance--;
      _hintsUsed++;
      
      if (_showErrors) {
        _updateErrorStates();
      }
      
      _checkPuzzleCompletion();
    });

    SoundService.playHint();
    VibrationService.hintUsed();

    if (kDebugMode) {
      print('✅ Hint used successfully: $hintValue at (${_selectedRow!}, ${_selectedCol!})');
    }
  }

  // Restart game functionality
  void _restartGame() {
    // FIXED: Stop and reset timer completely
    GameTimerService.stop();
    
    setState(() {
      // Reset ALL game state variables
      _selectedRow = null;
      _selectedCol = null;
      _isPuzzleComplete = false;
      _noteMode = false;
      _hintsUsed = 0;
      _errorCount = 0;
      _gameBlocked = false;
      
      // Generate a completely new puzzle using enhanced generator
      if (kDebugMode) {
        print('🔄 Generating new ${widget.difficulty} puzzle for restart...');
        SudokuGenerator.resetMetrics();
      }
      
      _puzzle = SudokuGenerator.generatePuzzle(widget.difficulty);
      
      if (kDebugMode) {
        print('✅ New puzzle generated for restart');
        print('📈 Metrics: ${SudokuGenerator.getMetrics()}');
      }
      
      // Generate new solution
      _solution = _puzzle.map((row) => List<int>.from(row)).toList();
      _solvePuzzle(_solution);
      
      // Reset all tracking arrays
      _isFixed = List.generate(9, (i) => List.generate(9, (j) => _puzzle[i][j] != 0));
      _isError = List.generate(9, (i) => List.filled(9, false));
      _isHint = List.generate(9, (i) => List.filled(9, false));
      _cornerNotes = List.generate(9, (i) => List.generate(9, (j) => <int>{}));
    });
    
    // Delete any saved game since we're restarting
    GameSaveService.deleteSavedGame();
    
    // FIXED: Start fresh timer after restart
    GameTimerService.start(onTimeUpdate: (seconds) {
      // The timer update will be handled by GameInfoTop widget
    });
    
    // Play restart sound and vibration
    SoundService.playButton();
    VibrationService.medium();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New puzzle generated!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Game info header (top) - Timer and restart
            GameInfoTop(
              difficulty: widget.difficulty,
              initialTime: widget.initialGameTime,
              onRestartGame: () {
                _restartGame(); // Call local restart logic
                widget.onRestartGame?.call(); // Call parent callback
              },
            ),
            
            // Sudoku board
            SudokuBoard(
              puzzle: _puzzle,
              isFixed: _isFixed,
              isError: _isError,
              isHint: _isHint,
              cornerNotes: _cornerNotes,
              selectedRow: _selectedRow,
              selectedCol: _selectedCol,
              onCellTap: _selectCell,
              scaleAnimation: _scaleAnimation,
            ),

            // Game info bottom - Hints, errors, mode - FIXED: Dynamic max errors
            GameInfoBottom(
              hintBalance: _hintBalance,
              noteMode: _noteMode,
              errorCount: _errorCount,
              maxErrors: _maxErrorsForUser, // Dynamic based on Remove Ads
            ),
            
            const SizedBox(height: 8),
            
            // Number pad (disabled when game is blocked)
            Expanded(
              child: Opacity(
                opacity: _gameBlocked ? 0.5 : 1.0,
                child: AbsorbPointer(
                  absorbing: _gameBlocked,
                  child: NumberPad(
                    onNumberPressed: _enterNumber,
                    onHintPressed: _useHint,
                    onToggleNoteMode: _toggleNoteMode,
                    onClearPressed: _clearCell,
                    noteMode: _noteMode,
                    hintBalance: _hintBalance,
                  ),
                ),
              ),
            ),
            
            // FIXED: Game blocked overlay message - Only for free users
            if (_gameBlocked && AdHelper.shouldShowAds())
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Game paused due to too many errors. Watch an ad to continue or purchase Remove Ads for unlimited play.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}