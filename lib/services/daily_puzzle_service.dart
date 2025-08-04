// daily_puzzle_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'sudoku_generator.dart';

class DailyPuzzleService {
  static const String _dailyPuzzleKey = 'daily_puzzle';
  static const String _dailyPuzzleDateKey = 'daily_puzzle_date';
  static const String _dailyPuzzleCompletedKey = 'daily_puzzle_completed';

  /// Gets today's daily puzzle
  static Future<Map<String, dynamic>> getTodaysPuzzle() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    // Check if we already have today's puzzle
    final savedDate = prefs.getString(_dailyPuzzleDateKey);
    final savedPuzzle = prefs.getString(_dailyPuzzleKey);
    final isCompleted = prefs.getBool('${_dailyPuzzleCompletedKey}_$todayString') ?? false;
    
    if (savedDate == todayString && savedPuzzle != null) {
      // Return existing puzzle
      final puzzleData = json.decode(savedPuzzle);
      return {
        'puzzle': List<List<int>>.from(
          puzzleData['puzzle'].map((row) => List<int>.from(row))
        ),
        'solution': List<List<int>>.from(
          puzzleData['solution'].map((row) => List<int>.from(row))
        ),
        'difficulty': puzzleData['difficulty'],
        'date': todayString,
        'completed': isCompleted,
      };
    }
    
    // Generate new daily puzzle
    final difficulty = _getDailyDifficulty(today);
    final puzzle = SudokuGenerator.generatePuzzle(difficulty);
    final solution = _solvePuzzle(puzzle);
    
    final puzzleData = {
      'puzzle': puzzle,
      'solution': solution,
      'difficulty': difficulty,
    };
    
    // Save the puzzle
    await prefs.setString(_dailyPuzzleKey, json.encode(puzzleData));
    await prefs.setString(_dailyPuzzleDateKey, todayString);
    
    return {
      'puzzle': puzzle,
      'solution': solution,
      'difficulty': difficulty,
      'date': todayString,
      'completed': false,
    };
  }

  /// Determines difficulty based on day of week
  static String _getDailyDifficulty(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
        return 'easy';
      case DateTime.wednesday:
      case DateTime.thursday:
        return 'medium';
      case DateTime.friday:
      case DateTime.saturday:
      case DateTime.sunday:
        return 'hard';
      default:
        return 'medium';
    }
  }

  /// Marks today's puzzle as completed
  static Future<void> markTodaysCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    await prefs.setBool('${_dailyPuzzleCompletedKey}_$todayString', true);
    await updateStats();
  }

  /// Gets completion statistics
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'totalCompleted': prefs.getInt('total_daily_completed') ?? 0,
      'currentStreak': prefs.getInt('current_streak') ?? 0,
      'longestStreak': prefs.getInt('longest_streak') ?? 0,
    };
  }

  /// Updates statistics when a daily puzzle is completed
  static Future<void> updateStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Increment total completed
    int totalCompleted = (prefs.getInt('total_daily_completed') ?? 0) + 1;
    await prefs.setInt('total_daily_completed', totalCompleted);
    
    // Update streak
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayString = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    
    bool yesterdayCompleted = prefs.getBool('${_dailyPuzzleCompletedKey}_$yesterdayString') ?? false;
    int currentStreak = prefs.getInt('current_streak') ?? 0;
    
    if (yesterdayCompleted || currentStreak == 0) {
      // Continue or start streak
      currentStreak++;
    } else {
      // Reset streak
      currentStreak = 1;
    }
    
    await prefs.setInt('current_streak', currentStreak);
    
    // Update longest streak
    int longestStreak = prefs.getInt('longest_streak') ?? 0;
    if (currentStreak > longestStreak) {
      await prefs.setInt('longest_streak', currentStreak);
    }
  }

  /// Checks if user has completed puzzle today
  static Future<bool> hasCompletedToday() async {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    final prefs = await SharedPreferences.getInstance();
    
    return prefs.getBool('${_dailyPuzzleCompletedKey}_$todayString') ?? false;
  }

  /// Solves a puzzle to get the solution
  static List<List<int>> _solvePuzzle(List<List<int>> puzzle) {
    List<List<int>> solution = puzzle.map((row) => List<int>.from(row)).toList();
    
    if (_solveSudokuBacktrack(solution)) {
      return solution;
    }
    
    // If solving fails, return the original puzzle
    return puzzle;
  }

  /// Backtracking solver for Sudoku
  static bool _solveSudokuBacktrack(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (_isValidMove(grid, row, col, num)) {
              grid[row][col] = num;
              
              if (_solveSudokuBacktrack(grid)) {
                return true;
              }
              
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  /// Validates if a move is legal
  static bool _isValidMove(List<List<int>> grid, int row, int col, int num) {
    // Check row
    for (int i = 0; i < 9; i++) {
      if (i != col && grid[row][i] == num) return false;
    }
    
    // Check column
    for (int i = 0; i < 9; i++) {
      if (i != row && grid[i][col] == num) return false;
    }
    
    // Check 3x3 box
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if ((i != row || j != col) && grid[i][j] == num) return false;
      }
    }
    
    return true;
  }
}