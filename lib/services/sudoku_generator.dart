// Enhanced sudoku_generator.dart - Now with solution uniqueness verification
import 'dart:math';
import 'package:flutter/foundation.dart';

class SudokuGenerator {
  static const int _size = 9;
  static final Random _random = Random();

  /// Enhanced difficulty configuration with uniqueness requirements
  static const Map<String, Map<String, dynamic>> _difficultyConfig = {
    'easy': {
      'cellsToRemove': 32,      // 49 clues remaining
      'minClues': 45,           // Higher minimum for reliability
      'description': 'Perfect for beginners',
      'maxAttempts': 50,
      'requireUnique': true,    // NEW: Ensure unique solution
    },
    'medium': {
      'cellsToRemove': 42,      // 39 clues remaining  
      'minClues': 35,           // Balanced minimum
      'description': 'Good challenge for regular players',
      'maxAttempts': 100,
      'requireUnique': true,    // NEW: Ensure unique solution
    },
    'hard': {
      'cellsToRemove': 52,      // 29 clues remaining
      'minClues': 25,           // Challenging but solvable
      'description': 'Expert level challenge',
      'maxAttempts': 200,
      'requireUnique': true,    // NEW: Ensure unique solution
    },
  };

  /// Performance metrics for debugging
  static Map<String, int> _metrics = {
    'transformations_applied': 0,
    'cells_removal_attempts': 0,
    'uniqueness_checks': 0,
    'generation_time_ms': 0,
  };

  /// Pre-generated valid complete grids for faster generation
  static final List<List<List<int>>> _seedGrids = [
    // Seed Grid 1
    [
      [5, 3, 4, 6, 7, 8, 9, 1, 2],
      [6, 7, 2, 1, 9, 5, 3, 4, 8],
      [1, 9, 8, 3, 4, 2, 5, 6, 7],
      [8, 5, 9, 7, 6, 1, 4, 2, 3],
      [4, 2, 6, 8, 5, 3, 7, 9, 1],
      [7, 1, 3, 9, 2, 4, 8, 5, 6],
      [9, 6, 1, 5, 3, 7, 2, 8, 4],
      [2, 8, 7, 4, 1, 9, 6, 3, 5],
      [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ],
    // Seed Grid 2
    [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ],
    // Seed Grid 3
    [
      [9, 1, 2, 3, 4, 5, 6, 7, 8],
      [3, 4, 5, 6, 7, 8, 9, 1, 2],
      [6, 7, 8, 9, 1, 2, 3, 4, 5],
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
    ],
  ];

  /// NEW: Solution uniqueness checker
  static int _countSolutions(List<List<int>> puzzle, {int maxSolutions = 2}) {
    List<List<int>> grid = puzzle.map((row) => List<int>.from(row)).toList();
    int solutionCount = 0;
    
    void backtrack() {
      if (solutionCount >= maxSolutions) return; // Early termination
      
      // Find first empty cell
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (grid[row][col] == 0) {
            // Try each number
            for (int num = 1; num <= 9; num++) {
              if (isValidMove(grid, row, col, num)) {
                grid[row][col] = num;
                backtrack();
                grid[row][col] = 0; // Backtrack
                
                if (solutionCount >= maxSolutions) return;
              }
            }
            return; // No valid numbers found
          }
        }
      }
      
      // If we reach here, puzzle is complete
      solutionCount++;
    }
    
    backtrack();
    return solutionCount;
  }

  /// NEW: Check if puzzle has unique solution
  static bool hasUniqueSolution(List<List<int>> puzzle) {
    _metrics['uniqueness_checks'] = (_metrics['uniqueness_checks'] ?? 0) + 1;
    
    final stopwatch = Stopwatch()..start();
    final count = _countSolutions(puzzle, maxSolutions: 2);
    stopwatch.stop();
    
    if (kDebugMode && stopwatch.elapsedMilliseconds > 100) {
      print('⏱️ Uniqueness check took ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return count == 1;
  }

  /// Use the EXACT same validation logic as the game
  static bool isValidMove(List<List<int>> grid, int row, int col, int num) {
    // Don't validate empty cells
    if (num == 0) return true;
    
    // Check row - exclude the current cell
    for (int i = 0; i < 9; i++) {
      if (i != col && grid[row][i] == num) {
        return false;
      }
    }
    
    // Check column - exclude the current cell
    for (int i = 0; i < 9; i++) {
      if (i != row && grid[i][col] == num) {
        return false;
      }
    }
    
    // Check 3x3 box - exclude the current cell
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if ((i != row || j != col) && grid[i][j] == num) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Optimized validation of entire puzzle state
  static bool validatePuzzleState(List<List<int>> puzzle) {
    // Quick check: ensure no obvious conflicts
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (puzzle[row][col] != 0) {
          List<List<int>> tempGrid = puzzle.map((row) => List<int>.from(row)).toList();
          int currentValue = tempGrid[row][col];
          tempGrid[row][col] = 0;
          
          if (!isValidMove(tempGrid, row, col, currentValue)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// Get difficulty information
  static Map<String, dynamic> getDifficultyInfo(String difficulty) {
    return _difficultyConfig[difficulty.toLowerCase()] ?? _difficultyConfig['medium']!;
  }

  /// Get all available difficulties
  static List<String> getAvailableDifficulties() {
    return _difficultyConfig.keys.toList();
  }

  /// Get generation metrics
  static Map<String, int> getMetrics() => Map.from(_metrics);

  /// Reset metrics
  static void resetMetrics() {
    _metrics = {
      'transformations_applied': 0,
      'cells_removal_attempts': 0,
      'uniqueness_checks': 0,
      'generation_time_ms': 0,
    };
  }

  /// Main generation method with uniqueness verification
  static List<List<int>> generatePuzzle(String difficulty) {
    if (kDebugMode) print('🎯 Generating ${difficulty.toUpperCase()} Sudoku puzzle with uniqueness verification...');
    final overallStopwatch = Stopwatch()..start();
    resetMetrics(); // Reset metrics for this generation
    
    final diffInfo = getDifficultyInfo(difficulty);
    List<List<int>>? puzzle;
    
    // Try multiple approaches for reliability
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (kDebugMode) print('🔄 Generation attempt $attempt...');
      
      switch (attempt) {
        case 1:
          puzzle = _generateFromSeed(difficulty);
          break;
        case 2:
          puzzle = _generateWithSimpleRemoval(difficulty);
          break;
        case 3:
          puzzle = _generateFallback(difficulty);
          break;
      }
      
      // Validate the generated puzzle
      if (puzzle != null && validatePuzzleState(puzzle)) {
        // Check uniqueness if required
        if (diffInfo['requireUnique'] == true) {
          if (hasUniqueSolution(puzzle)) {
            overallStopwatch.stop();
            _metrics['generation_time_ms'] = overallStopwatch.elapsedMilliseconds;
            
            if (kDebugMode) {
              print('✅ Generated unique puzzle in ${overallStopwatch.elapsedMilliseconds}ms (attempt $attempt)');
              print('📊 Clues: ${_countClues(puzzle)}/81');
              print('📈 Metrics: $_metrics');
            }
            return puzzle;
          } else {
            if (kDebugMode) print('❌ Generated puzzle has multiple solutions, trying again...');
          }
        } else {
          // Uniqueness not required
          overallStopwatch.stop();
          _metrics['generation_time_ms'] = overallStopwatch.elapsedMilliseconds;
          
          if (kDebugMode) {
            print('✅ Generated valid puzzle in ${overallStopwatch.elapsedMilliseconds}ms (attempt $attempt)');
            print('📊 Clues: ${_countClues(puzzle)}/81');
          }
          return puzzle;
        }
      } else if (puzzle != null) {
        if (kDebugMode) print('❌ Generated puzzle failed validation, trying again...');
      }
    }
    
    // Ultimate fallback
    overallStopwatch.stop();
    _metrics['generation_time_ms'] = overallStopwatch.elapsedMilliseconds;
    
    if (kDebugMode) print('⚠️ Using emergency fallback grid');
    return _generateEmergencyFallback(difficulty);
  }

  /// Fast generation using seed grids with transformations
  static List<List<int>>? _generateFromSeed(String difficulty) {
    try {
      final seedGrid = _seedGrids[_random.nextInt(_seedGrids.length)];
      List<List<int>> grid = _applyTransformations(seedGrid);
      return _removeCellsWithUniqueness(grid, difficulty);
    } catch (e) {
      if (kDebugMode) print('⚠️ Seed generation failed: $e');
      return null;
    }
  }

  /// NEW: Enhanced cell removal with uniqueness checking
  static List<List<int>>? _removeCellsWithUniqueness(List<List<int>> complete, String difficulty) {
    List<List<int>> puzzle = complete.map((row) => List<int>.from(row)).toList();
    final diffInfo = getDifficultyInfo(difficulty);
    
    int targetCellsToRemove = diffInfo['cellsToRemove'];
    int minClues = diffInfo['minClues'];
    bool requireUnique = diffInfo['requireUnique'] ?? false;
    
    // Create removal candidates with strategic ordering
    List<List<int>> positions = _createSmartRemovalOrder();
    
    int removed = 0;
    int attempts = 0;
    const maxAttempts = 100;
    
    for (List<int> pos in positions) {
      if (removed >= targetCellsToRemove || attempts >= maxAttempts) break;
      
      attempts++;
      _metrics['cells_removal_attempts'] = (_metrics['cells_removal_attempts'] ?? 0) + 1;
      
      int row = pos[0];
      int col = pos[1];
      int backup = puzzle[row][col];
      
      if (backup == 0) continue; // Already empty
      
      // Temporarily remove the number
      puzzle[row][col] = 0;
      
      bool shouldKeepRemoval = true;
      int currentClues = _countClues(puzzle);
      
      // Check minimum clues requirement
      if (currentClues < minClues) {
        shouldKeepRemoval = false;
      }
      
      // Check basic validity
      if (shouldKeepRemoval && !validatePuzzleState(puzzle)) {
        shouldKeepRemoval = false;
      }
      
      // Check uniqueness if required (more expensive, so do it last)
      if (shouldKeepRemoval && requireUnique) {
        // Only check uniqueness every few removals for performance
        if (removed % 5 == 0 || removed > targetCellsToRemove - 10) {
          shouldKeepRemoval = hasUniqueSolution(puzzle);
        }
      }
      
      if (shouldKeepRemoval) {
        removed++;
        if (kDebugMode && removed % 10 == 0) {
          print('📍 Removed $removed/$targetCellsToRemove cells (${requireUnique ? 'unique' : 'valid'})');
        }
      } else {
        // Restore if removal makes puzzle invalid/non-unique
        puzzle[row][col] = backup;
      }
    }
    
    // Final uniqueness check if required
    if (requireUnique && !hasUniqueSolution(puzzle)) {
      if (kDebugMode) print('❌ Final uniqueness check failed');
      return null;
    }
    
    final finalClues = _countClues(puzzle);
    if (kDebugMode) {
      print('🎯 Final puzzle: $finalClues clues, difficulty: $difficulty, unique: ${requireUnique ? 'verified' : 'not checked'}');
    }
    
    return finalClues >= minClues ? puzzle : null;
  }

  /// NEW: Smart removal order prioritizing strategic positions
  static List<List<int>> _createSmartRemovalOrder() {
    List<List<int>> positions = [];
    
    // Add center cells first (often less critical)
    for (int i = 3; i <= 5; i++) {
      for (int j = 3; j <= 5; j++) {
        positions.add([i, j]);
      }
    }
    
    // Add corner and edge cells
    List<List<int>> corners = [[0,0], [0,8], [8,0], [8,8]];
    List<List<int>> edges = [];
    
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (i == 0 || i == 8 || j == 0 || j == 8) {
          if (!corners.any((corner) => corner[0] == i && corner[1] == j)) {
            edges.add([i, j]);
          }
        }
      }
    }
    
    // Add remaining positions
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        bool alreadyAdded = positions.any((pos) => pos[0] == i && pos[1] == j) ||
                           corners.any((pos) => pos[0] == i && pos[1] == j) ||
                           edges.any((pos) => pos[0] == i && pos[1] == j);
        if (!alreadyAdded) {
          positions.add([i, j]);
        }
      }
    }
    
    // Add corners and edges at the end (more critical for uniqueness)
    positions.addAll(edges);
    positions.addAll(corners);
    
    // Shuffle within each category for variety
    positions.shuffle(_random);
    
    return positions;
  }

  /// Apply random transformations to make grid unique
  static List<List<int>> _applyTransformations(List<List<int>> originalGrid) {
    List<List<int>> grid = originalGrid.map((row) => List<int>.from(row)).toList();
    
    final numTransformations = 4 + _random.nextInt(4); // 4-7 transformations
    _metrics['transformations_applied'] = numTransformations;
    
    for (int i = 0; i < numTransformations; i++) {
      final transformation = _random.nextInt(6);
      
      switch (transformation) {
        case 0: grid = _swapRows(grid); break;
        case 1: grid = _swapColumns(grid); break;
        case 2: grid = _swapRowBlocks(grid); break;
        case 3: grid = _swapColumnBlocks(grid); break;
        case 4: grid = _transposeGrid(grid); break;
        case 5: grid = _swapNumbers(grid); break;
      }
    }
    
    return grid;
  }

  /// Simple removal approach as backup
  static List<List<int>>? _generateWithSimpleRemoval(String difficulty) {
    final seedGrid = _seedGrids[1];
    List<List<int>> grid = _applyTransformations(seedGrid);
    return _removeCellsWithUniqueness(grid, difficulty);
  }

  /// Fallback generation
  static List<List<int>>? _generateFallback(String difficulty) {
    final fallbackGrid = _seedGrids[2];
    List<List<int>> grid = _applyTransformations(fallbackGrid);
    return _removeCellsWithUniqueness(grid, difficulty);
  }

  /// Emergency fallback - always works (may not be unique)
  static List<List<int>> _generateEmergencyFallback(String difficulty) {
    final grid = _seedGrids[0];
    final puzzle = grid.map((row) => List<int>.from(row)).toList();
    
    final diffInfo = getDifficultyInfo(difficulty);
    int toRemove = diffInfo['cellsToRemove'];
    
    List<List<int>> positions = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        positions.add([i, j]);
      }
    }
    positions.shuffle(_random);
    
    for (int i = 0; i < toRemove && i < positions.length; i++) {
      puzzle[positions[i][0]][positions[i][1]] = 0;
    }
    
    return puzzle;
  }

  // Transformation methods (unchanged)
  static List<List<int>> _swapRows(List<List<int>> grid) {
    final block = _random.nextInt(3);
    final row1 = block * 3 + _random.nextInt(3);
    final row2 = block * 3 + _random.nextInt(3);
    
    if (row1 != row2) {
      final temp = List<int>.from(grid[row1]);
      grid[row1] = List<int>.from(grid[row2]);
      grid[row2] = temp;
    }
    return grid;
  }

  static List<List<int>> _swapColumns(List<List<int>> grid) {
    final block = _random.nextInt(3);
    final col1 = block * 3 + _random.nextInt(3);
    final col2 = block * 3 + _random.nextInt(3);
    
    if (col1 != col2) {
      for (int i = 0; i < 9; i++) {
        final temp = grid[i][col1];
        grid[i][col1] = grid[i][col2];
        grid[i][col2] = temp;
      }
    }
    return grid;
  }

  static List<List<int>> _swapRowBlocks(List<List<int>> grid) {
    final block1 = _random.nextInt(3);
    final block2 = _random.nextInt(3);
    
    if (block1 != block2) {
      for (int i = 0; i < 3; i++) {
        final temp = List<int>.from(grid[block1 * 3 + i]);
        grid[block1 * 3 + i] = List<int>.from(grid[block2 * 3 + i]);
        grid[block2 * 3 + i] = temp;
      }
    }
    return grid;
  }

  static List<List<int>> _swapColumnBlocks(List<List<int>> grid) {
    final block1 = _random.nextInt(3);
    final block2 = _random.nextInt(3);
    
    if (block1 != block2) {
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 3; j++) {
          final temp = grid[i][block1 * 3 + j];
          grid[i][block1 * 3 + j] = grid[i][block2 * 3 + j];
          grid[i][block2 * 3 + j] = temp;
        }
      }
    }
    return grid;
  }

  static List<List<int>> _transposeGrid(List<List<int>> grid) {
    List<List<int>> transposed = List.generate(9, (_) => List.filled(9, 0));
    
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        transposed[j][i] = grid[i][j];
      }
    }
    return transposed;
  }

  static List<List<int>> _swapNumbers(List<List<int>> grid) {
    final num1 = 1 + _random.nextInt(9);
    final num2 = 1 + _random.nextInt(9);
    
    if (num1 != num2) {
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (grid[i][j] == num1) {
            grid[i][j] = num2;
          } else if (grid[i][j] == num2) {
            grid[i][j] = num1;
          }
        }
      }
    }
    return grid;
  }

  /// Utility methods
  static int _countClues(List<List<int>> puzzle) {
    int count = 0;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (puzzle[i][j] != 0) count++;
      }
    }
    return count;
  }

  /// Legacy methods for compatibility
  static bool isValidSolution(List<List<int>> grid) {
    for (int i = 0; i < 9; i++) {
      if (!_isValidGroup(_getRow(grid, i)) ||
          !_isValidGroup(_getColumn(grid, i))) {
        return false;
      }
    }
    
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        if (!_isValidGroup(_getBox(grid, boxRow, boxCol))) {
          return false;
        }
      }
    }
    
    return true;
  }

  static bool _isValidGroup(List<int> group) {
    if (group.length != 9) return false;
    List<bool> seen = List.filled(10, false);
    
    for (int num in group) {
      if (num < 1 || num > 9 || seen[num]) return false;
      seen[num] = true;
    }
    return true;
  }

  static List<int> _getRow(List<List<int>> grid, int row) => grid[row];
  static List<int> _getColumn(List<List<int>> grid, int col) => 
      [for (int i = 0; i < 9; i++) grid[i][col]];
  
  static List<int> _getBox(List<List<int>> grid, int boxRow, int boxCol) {
    List<int> box = [];
    int startRow = boxRow * 3;
    int startCol = boxCol * 3;
    
    for (int i = startRow; i < startRow + 3; i++) {
      for (int j = startCol; j < startCol + 3; j++) {
        box.add(grid[i][j]);
      }
    }
    return box;
  }

  /// Get hint for next move with proper return type
  static Map<String, int>? getHint(List<List<int>> puzzle) {
    List<List<int>> solution = puzzle.map((row) => List<int>.from(row)).toList();
    if (_solvePuzzle(solution)) {
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (puzzle[i][j] == 0) {
            return <String, int>{
              'row': i, 
              'col': j, 
              'value': solution[i][j]
            };
          }
        }
      }
    }
    return null;
  }

  static bool _solvePuzzle(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (isValidMove(grid, row, col, num)) {
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

  /// Enhanced debugging method
  static void debugPuzzle(List<List<int>> puzzle) {
    if (kDebugMode) {
      print('🔍 === ENHANCED PUZZLE DEBUG ===');
      print('📊 Clues: ${_countClues(puzzle)}/81');
      print('✅ Valid state: ${validatePuzzleState(puzzle)}');
      print('🎯 Unique solution: ${hasUniqueSolution(puzzle)}');
      print('📈 Generation metrics: $_metrics');
      print('🔍 === END DEBUG ===');
    }
  }

  /// NEW: Comprehensive testing method
  static void testEnhancedGeneration() {
    if (kDebugMode) {
      print('\n🧪 Testing Enhanced Sudoku Generation with Uniqueness...\n');
      
      for (String difficulty in getAvailableDifficulties()) {
        print('--- Testing $difficulty ---');
        resetMetrics();
        
        final stopwatch = Stopwatch()..start();
        final puzzle = generatePuzzle(difficulty);
        stopwatch.stop();
        
        final clues = _countClues(puzzle);
        final isValid = validatePuzzleState(puzzle);
        final isUnique = hasUniqueSolution(puzzle);
        final metrics = getMetrics();
        
        print('Generated in: ${stopwatch.elapsedMilliseconds}ms');
        print('Clues: $clues/81');
        print('Valid: ${isValid ? '✅' : '❌'}');
        print('Unique solution: ${isUnique ? '✅' : '❌'}');
        print('Metrics: $metrics');
        print('✅ $difficulty puzzle generated successfully\n');
      }
    }
  }
}