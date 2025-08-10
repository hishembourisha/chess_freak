// lib/helpers/chess_game_helper.dart
// Helper functions to work with the chess engine

import '../services/chess_engine.dart';

class ChessGameHelper {
  
  /// Convert your ChessMove to a Position-based format if needed
  static Map<String, dynamic> moveToMap(ChessMove move) {
    return {
      'fromRow': move.fromRow,
      'fromCol': move.fromCol,
      'toRow': move.toRow,
      'toCol': move.toCol,
      'capturedPiece': move.capturedPiece != null ? {
        'type': move.capturedPiece!.type.name,
        'color': move.capturedPiece!.color.name,
        'hasMoved': move.capturedPiece!.hasMoved,
      } : null,
      'isEnPassant': move.isEnPassant,
      'isCastling': move.isCastling,
      'promotionPiece': move.promotionPiece?.name,
    };
  }

  /// Convert map back to ChessMove if needed for save/load
  static ChessMove moveFromMap(Map<String, dynamic> map) {
    ChessPiece? capturedPiece;
    if (map['capturedPiece'] != null) {
      final capturedData = map['capturedPiece'] as Map<String, dynamic>;
      capturedPiece = ChessPiece(
        type: PieceType.values.firstWhere((e) => e.name == capturedData['type']),
        color: PieceColor.values.firstWhere((e) => e.name == capturedData['color']),
        hasMoved: capturedData['hasMoved'] ?? false,
      );
    }

    PieceType? promotionPiece;
    if (map['promotionPiece'] != null) {
      promotionPiece = PieceType.values.firstWhere((e) => e.name == map['promotionPiece']);
    }

    return ChessMove(
      fromRow: map['fromRow'],
      fromCol: map['fromCol'],
      toRow: map['toRow'],
      toCol: map['toCol'],
      capturedPiece: capturedPiece,
      isEnPassant: map['isEnPassant'] ?? false,
      isCastling: map['isCastling'] ?? false,
      promotionPiece: promotionPiece,
    );
  }

  /// Convert board state to serializable format
  static List<List<Map<String, dynamic>?>> boardToMap(List<List<ChessPiece?>> board) {
    return board.map((row) => 
      row.map((piece) => piece != null ? {
        'type': piece.type.name,
        'color': piece.color.name,
        'hasMoved': piece.hasMoved,
      } : null).toList()
    ).toList();
  }

  /// Convert serializable format back to board
  static List<List<ChessPiece?>> boardFromMap(List<List<Map<String, dynamic>?>> mapBoard) {
    return mapBoard.map((row) => 
      row.map((pieceMap) => pieceMap != null ? ChessPiece(
        type: PieceType.values.firstWhere((e) => e.name == pieceMap['type']),
        color: PieceColor.values.firstWhere((e) => e.name == pieceMap['color']),
        hasMoved: pieceMap['hasMoved'] ?? false,
      ) : null).toList()
    ).toList();
  }

  /// Get game state for saving
  static Map<String, dynamic> getGameStateForSaving(ChessEngine engine) {
    return {
      'board': boardToMap(engine.board),
      'currentPlayer': engine.currentPlayer.name,
      'difficulty': engine.difficulty.name,
      'gameState': engine.gameState.name,
      'whiteCaptured': engine.whiteCaptured.map((p) => {
        'type': p.type.name,
        'color': p.color.name,
        'hasMoved': p.hasMoved,
      }).toList(),
      'blackCaptured': engine.blackCaptured.map((p) => {
        'type': p.type.name,
        'color': p.color.name,
        'hasMoved': p.hasMoved,
      }).toList(),
      'moveHistory': engine.moveHistory.map(moveToMap).toList(),
      'lastMove': engine.lastMove != null ? moveToMap(engine.lastMove!) : null,
      'whiteKingMoved': engine.whiteKingMoved,
      'blackKingMoved': engine.blackKingMoved,
      'whiteKingSideRookMoved': engine.whiteKingSideRookMoved,
      'whiteQueenSideRookMoved': engine.whiteQueenSideRookMoved,
      'blackKingSideRookMoved': engine.blackKingSideRookMoved,
      'blackQueenSideRookMoved': engine.blackQueenSideRookMoved,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'moveCount': engine.moveHistory.length,
      'playerColor': 'white', // Assuming player is always white
    };
  }

  /// Restore game state from saved data
  static ChessEngine restoreGameState(Map<String, dynamic> savedData) {
    final engine = ChessEngine(
      difficulty: Difficulty.values.firstWhere((e) => e.name == savedData['difficulty'])
    );

    // Restore board
    engine.board = boardFromMap(List<List<Map<String, dynamic>?>>.from(savedData['board']));
    
    // Restore current player
    engine.currentPlayer = PieceColor.values.firstWhere((e) => e.name == savedData['currentPlayer']);
    
    // Restore game state
    engine.gameState = GameState.values.firstWhere((e) => e.name == savedData['gameState']);
    
    // Restore captured pieces
    engine.whiteCaptured = (savedData['whiteCaptured'] as List).map((p) => ChessPiece(
      type: PieceType.values.firstWhere((e) => e.name == p['type']),
      color: PieceColor.values.firstWhere((e) => e.name == p['color']),
      hasMoved: p['hasMoved'] ?? false,
    )).toList();
    
    engine.blackCaptured = (savedData['blackCaptured'] as List).map((p) => ChessPiece(
      type: PieceType.values.firstWhere((e) => e.name == p['type']),
      color: PieceColor.values.firstWhere((e) => e.name == p['color']),
      hasMoved: p['hasMoved'] ?? false,
    )).toList();
    
    // Restore move history
    engine.moveHistory = (savedData['moveHistory'] as List).map((m) => moveFromMap(m)).toList();
    
    // Restore last move
    if (savedData['lastMove'] != null) {
      engine.lastMove = moveFromMap(savedData['lastMove']);
    }
    
    // Restore special move flags
    engine.whiteKingMoved = savedData['whiteKingMoved'] ?? false;
    engine.blackKingMoved = savedData['blackKingMoved'] ?? false;
    engine.whiteKingSideRookMoved = savedData['whiteKingSideRookMoved'] ?? false;
    engine.whiteQueenSideRookMoved = savedData['whiteQueenSideRookMoved'] ?? false;
    engine.blackKingSideRookMoved = savedData['blackKingSideRookMoved'] ?? false;
    engine.blackQueenSideRookMoved = savedData['blackQueenSideRookMoved'] ?? false;

    return engine;
  }

  /// Get display name for piece color
  static String getColorDisplayName(PieceColor color) {
    return color == PieceColor.white ? 'White' : 'Black';
  }

  /// Get display name for game state
  static String getGameStateDisplayName(GameState state) {
    switch (state) {
      case GameState.playing:
        return 'Playing';
      case GameState.check:
        return 'Check';
      case GameState.checkmate:
        return 'Checkmate';
      case GameState.stalemate:
        return 'Stalemate';
      case GameState.draw:
        return 'Draw';
    }
  }

  /// Check if a square is a light square (for board coloring)
  static bool isLightSquare(int row, int col) {
    return (row + col) % 2 == 0;
  }
}