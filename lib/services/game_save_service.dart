// lib/services/game_save_service.dart - Fixed type handling
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GameSaveService {
  static const String _saveKey = 'sudoku_game_save';
  
  /// Save the current game state
  static Future<bool> saveGame({
    required String difficulty,
    required List<List<int>> puzzle,
    required List<List<int>> solution,
    required List<List<bool>> isFixed,
    required List<List<bool>> isHint,
    required List<List<Set<int>>> cornerNotes,
    required int hintsUsed,
    required int errorCount,
    required bool noteMode,
    required int? selectedRow,
    required int? selectedCol,
    required int gameTime,
    required DateTime timestamp,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert the game state to a JSON-serializable map
      final gameData = {
        'difficulty': difficulty,
        'puzzle': puzzle,
        'solution': solution,
        'isFixed': isFixed,
        'isHint': isHint,
        'cornerNotes': cornerNotes.map((row) => 
          row.map((cell) => cell.toList()).toList()
        ).toList(),
        'hintsUsed': hintsUsed,
        'errorCount': errorCount,
        'noteMode': noteMode,
        'selectedRow': selectedRow,
        'selectedCol': selectedCol,
        'gameTime': gameTime,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'version': 1, // For future compatibility
      };
      
      final jsonString = jsonEncode(gameData);
      final success = await prefs.setString(_saveKey, jsonString);
      
      if (kDebugMode && success) {
        print('💾 Game saved successfully for difficulty: $difficulty');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save game: $e');
      }
      return false;
    }
  }
  
  /// Load the saved game state with proper type conversion
  static Future<Map<String, dynamic>?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);
      
      if (jsonString == null) {
        if (kDebugMode) {
          print('📂 No saved game found');
        }
        return null;
      }
      
      final gameData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Convert back to the correct types with safe casting
      final loadedData = {
        'difficulty': gameData['difficulty'] as String? ?? 'medium',
        
        // Convert puzzle data with proper type checking
        'puzzle': (gameData['puzzle'] as List?)?.map((row) => 
          (row as List?)?.map((cell) => (cell as num?)?.toInt() ?? 0).toList() ?? <int>[]
        ).toList() ?? <List<int>>[],
        
        'solution': (gameData['solution'] as List?)?.map((row) => 
          (row as List?)?.map((cell) => (cell as num?)?.toInt() ?? 0).toList() ?? <int>[]
        ).toList() ?? <List<int>>[],
        
        'isFixed': (gameData['isFixed'] as List?)?.map((row) => 
          (row as List?)?.map((cell) => (cell as bool?) ?? false).toList() ?? <bool>[]
        ).toList() ?? <List<bool>>[],
        
        'isHint': (gameData['isHint'] as List?)?.map((row) => 
          (row as List?)?.map((cell) => (cell as bool?) ?? false).toList() ?? <bool>[]
        ).toList() ?? <List<bool>>[],
        
        'cornerNotes': (gameData['cornerNotes'] as List?)?.map((row) => 
          (row as List?)?.map((cell) {
            if (cell is List) {
              // Cell is already a List from JSON, convert to Set<int>
              return cell.where((note) => note != null)
                        .map((note) => (note as num).toInt())
                        .toSet();
            } else {
              // Fallback: empty set
              return <int>{};
            }
          }).toList() ?? <Set<int>>[]
        ).toList() ?? <List<Set<int>>>[],
        
        // Safe casting for primitive types
        'hintsUsed': (gameData['hintsUsed'] as num?)?.toInt() ?? 0,
        'errorCount': (gameData['errorCount'] as num?)?.toInt() ?? 0,
        'noteMode': (gameData['noteMode'] as bool?) ?? false,
        'selectedRow': (gameData['selectedRow'] as num?)?.toInt(),
        'selectedCol': (gameData['selectedCol'] as num?)?.toInt(),
        'gameTime': (gameData['gameTime'] as num?)?.toInt() ?? 0,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (gameData['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch
        ),
        'version': (gameData['version'] as num?)?.toInt() ?? 1,
      };
      
      if (kDebugMode) {
        print('📂 Game loaded successfully: ${loadedData['difficulty']} from ${loadedData['timestamp']}');
      }
      
      return loadedData;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load game: $e');
      }
      return null;
    }
  }
  
  /// Check if there's a saved game available
  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_saveKey);
    } catch (e) {
      return false;
    }
  }
  
  /// Get basic info about the saved game without fully loading it
  static Future<Map<String, dynamic>?> getSavedGameInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);
      
      if (jsonString == null) return null;
      
      final gameData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Return just the basic info with safe casting
      return {
        'difficulty': gameData['difficulty'] as String? ?? 'medium',
        'hintsUsed': (gameData['hintsUsed'] as num?)?.toInt() ?? 0,
        'errorCount': (gameData['errorCount'] as num?)?.toInt() ?? 0,
        'gameTime': (gameData['gameTime'] as num?)?.toInt() ?? 0,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (gameData['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch
        ),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get saved game info: $e');
      }
      return null;
    }
  }
  
  /// Delete the saved game
  static Future<bool> deleteSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_saveKey);
      
      if (kDebugMode && success) {
        print('🗑️ Saved game deleted');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to delete saved game: $e');
      }
      return false;
    }
  }
  
  /// Calculate completion percentage of the saved game
  static int calculateProgress(List<List<int>> puzzle) {
    int filledCells = 0;
    int totalCells = 81;
    
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (puzzle[i][j] != 0) {
          filledCells++;
        }
      }
    }
    
    return ((filledCells / totalCells) * 100).round();
  }
  
  /// Get a human-readable time ago string
  static String getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}