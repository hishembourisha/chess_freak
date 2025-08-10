// File: lib/services/chess_save_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_engine.dart';

class ChessSaveService {
  static const String _saveKey = 'chess_saved_game';
  static const String _gameInfoKey = 'chess_game_info';

  /// Save the current chess game state
  static Future<bool> saveGame({
    required ChessEngine engine,
    required Difficulty difficulty,
    required bool isPlayerWhite,
    required int gameTime,
    required List<ChessMove> moveHistory,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create game data
      final gameData = {
        'board': _serializeBoard(engine.board),
        'currentPlayer': engine.currentPlayer.name,
        'difficulty': difficulty.name,
        'isPlayerWhite': isPlayerWhite,
        'gameTime': gameTime,
        'moveHistory': _serializeMoveHistory(moveHistory),
        'whiteCaptured': _serializePieces(engine.whiteCaptured),
        'blackCaptured': _serializePieces(engine.blackCaptured),
        'gameState': engine.gameState.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        
        // Special move flags
        'whiteKingMoved': engine.whiteKingMoved,
        'blackKingMoved': engine.blackKingMoved,
        'whiteKingSideRookMoved': engine.whiteKingSideRookMoved,
        'whiteQueenSideRookMoved': engine.whiteQueenSideRookMoved,
        'blackKingSideRookMoved': engine.blackKingSideRookMoved,
        'blackQueenSideRookMoved': engine.blackQueenSideRookMoved,
      };
      
      // Create game info for quick display
      final gameInfo = {
        'difficulty': difficulty.name,
        'playerColor': isPlayerWhite ? 'White' : 'Black',
        'moveCount': moveHistory.length,
        'gameTime': gameTime,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'gameState': engine.gameState.name,
      };
      
      // Save both full data and quick info
      final saveSuccess = await prefs.setString(_saveKey, jsonEncode(gameData));
      final infoSuccess = await prefs.setString(_gameInfoKey, jsonEncode(gameInfo));
      
      if (saveSuccess && infoSuccess) {
        print('✅ Chess game saved successfully');
        return true;
      } else {
        print('❌ Failed to save chess game');
        return false;
      }
    } catch (e) {
      print('❌ Error saving chess game: $e');
      return false;
    }
  }

  /// Check if there's a saved game
  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_saveKey) && prefs.getString(_saveKey) != null;
    } catch (e) {
      print('❌ Error checking for saved game: $e');
      return false;
    }
  }

  /// Get saved game info for display
  static Future<Map<String, dynamic>?> getSavedGameInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final infoString = prefs.getString(_gameInfoKey);
      
      if (infoString != null) {
        final info = jsonDecode(infoString);
        // Convert difficulty string back to enum
        info['difficulty'] = Difficulty.values.firstWhere(
          (d) => d.name == info['difficulty'],
          orElse: () => Difficulty.beginner,
        );
        return info;
      }
      return null;
    } catch (e) {
      print('❌ Error getting saved game info: $e');
      return null;
    }
  }

  /// Load the full game data
  static Future<Map<String, dynamic>?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameString = prefs.getString(_saveKey);
      
      if (gameString != null) {
        final gameData = jsonDecode(gameString);
        
        // Convert string enums back to actual enums
        gameData['difficulty'] = Difficulty.values.firstWhere(
          (d) => d.name == gameData['difficulty'],
          orElse: () => Difficulty.beginner,
        );
        
        gameData['currentPlayer'] = PieceColor.values.firstWhere(
          (c) => c.name == gameData['currentPlayer'],
          orElse: () => PieceColor.white,
        );
        
        gameData['gameState'] = GameState.values.firstWhere(
          (s) => s.name == gameData['gameState'],
          orElse: () => GameState.playing,
        );
        
        return gameData;
      }
      return null;
    } catch (e) {
      print('❌ Error loading saved game: $e');
      return null;
    }
  }

  /// Delete saved game
  static Future<bool> deleteSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final removeGame = await prefs.remove(_saveKey);
      final removeInfo = await prefs.remove(_gameInfoKey);
      
      if (removeGame && removeInfo) {
        print('✅ Saved chess game deleted');
        return true;
      } else {
        print('❌ Failed to delete saved chess game');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting saved game: $e');
      return false;
    }
  }

  /// Restore game state to engine
  static ChessEngine? restoreGameState(Map<String, dynamic> gameData) {
    try {
      final engine = ChessEngine(difficulty: gameData['difficulty']);
      
      // Restore board
      engine.board = _deserializeBoard(gameData['board']);
      
      // Restore game state
      engine.currentPlayer = gameData['currentPlayer'];
      engine.gameState = gameData['gameState'];
      
      // Restore captured pieces
      engine.whiteCaptured = _deserializePieces(gameData['whiteCaptured']);
      engine.blackCaptured = _deserializePieces(gameData['blackCaptured']);
      
      // Restore move history
      engine.moveHistory = _deserializeMoveHistory(gameData['moveHistory']);
      
      // Restore special move flags
      engine.whiteKingMoved = gameData['whiteKingMoved'] ?? false;
      engine.blackKingMoved = gameData['blackKingMoved'] ?? false;
      engine.whiteKingSideRookMoved = gameData['whiteKingSideRookMoved'] ?? false;
      engine.whiteQueenSideRookMoved = gameData['whiteQueenSideRookMoved'] ?? false;
      engine.blackKingSideRookMoved = gameData['blackKingSideRookMoved'] ?? false;
      engine.blackQueenSideRookMoved = gameData['blackQueenSideRookMoved'] ?? false;
      
      // Set last move if there's move history
      if (engine.moveHistory.isNotEmpty) {
        engine.lastMove = engine.moveHistory.last;
      }
      
      print('✅ Chess game state restored successfully');
      return engine;
    } catch (e) {
      print('❌ Error restoring game state: $e');
      return null;
    }
  }

  // Helper methods for serialization
  static List<List<Map<String, dynamic>?>> _serializeBoard(List<List<ChessPiece?>> board) {
    return board.map((row) => 
      row.map((piece) => piece != null ? {
        'type': piece.type.name,
        'color': piece.color.name,
        'hasMoved': piece.hasMoved,
      } : null).toList()
    ).toList();
  }

  static List<List<ChessPiece?>> _deserializeBoard(List<dynamic> boardData) {
    return boardData.map<List<ChessPiece?>>((row) => 
      (row as List).map<ChessPiece?>((pieceData) {
        if (pieceData == null) return null;
        
        final piece = ChessPiece(
          type: PieceType.values.firstWhere((t) => t.name == pieceData['type']),
          color: PieceColor.values.firstWhere((c) => c.name == pieceData['color']),
          hasMoved: pieceData['hasMoved'] ?? false,
        );
        return piece;
      }).toList()
    ).toList();
  }

  static List<Map<String, dynamic>> _serializePieces(List<ChessPiece> pieces) {
    return pieces.map((piece) => {
      'type': piece.type.name,
      'color': piece.color.name,
    }).toList();
  }

  static List<ChessPiece> _deserializePieces(List<dynamic> piecesData) {
    return piecesData.map<ChessPiece>((pieceData) => ChessPiece(
      type: PieceType.values.firstWhere((t) => t.name == pieceData['type']),
      color: PieceColor.values.firstWhere((c) => c.name == pieceData['color']),
    )).toList();
  }

  static List<Map<String, dynamic>> _serializeMoveHistory(List<ChessMove> moves) {
    return moves.map((move) => {
      'fromRow': move.fromRow,
      'fromCol': move.fromCol,
      'toRow': move.toRow,
      'toCol': move.toCol,
      'capturedPiece': move.capturedPiece != null ? {
        'type': move.capturedPiece!.type.name,
        'color': move.capturedPiece!.color.name,
      } : null,
      'isEnPassant': move.isEnPassant,
      'isCastling': move.isCastling,
      'promotionPiece': move.promotionPiece?.name,
    }).toList();
  }

  static List<ChessMove> _deserializeMoveHistory(List<dynamic> movesData) {
    return movesData.map<ChessMove>((moveData) => ChessMove(
      fromRow: moveData['fromRow'],
      fromCol: moveData['fromCol'],
      toRow: moveData['toRow'],
      toCol: moveData['toCol'],
      capturedPiece: moveData['capturedPiece'] != null ? ChessPiece(
        type: PieceType.values.firstWhere((t) => t.name == moveData['capturedPiece']['type']),
        color: PieceColor.values.firstWhere((c) => c.name == moveData['capturedPiece']['color']),
      ) : null,
      isEnPassant: moveData['isEnPassant'] ?? false,
      isCastling: moveData['isCastling'] ?? false,
      promotionPiece: moveData['promotionPiece'] != null 
          ? PieceType.values.firstWhere((t) => t.name == moveData['promotionPiece'])
          : null,
    )).toList();
  }

  /// Get time ago string for display
  static String getTimeAgo(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    final minutes = diff ~/ (1000 * 60);
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;
    
    if (days > 0) return '$days day${days == 1 ? '' : 's'} ago';
    if (hours > 0) return '$hours hour${hours == 1 ? '' : 's'} ago';
    if (minutes > 0) return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }

  /// Auto-save during gameplay
  static Future<void> autoSave({
    required ChessEngine engine,
    required Difficulty difficulty,
    required bool isPlayerWhite,
    required int gameTime,
  }) async {
    // Only auto-save if game is in progress (not finished)
    if (engine.gameState == GameState.playing || engine.gameState == GameState.check) {
      await saveGame(
        engine: engine,
        difficulty: difficulty,
        isPlayerWhite: isPlayerWhite,
        gameTime: gameTime,
        moveHistory: engine.moveHistory,
      );
    }
  }
}