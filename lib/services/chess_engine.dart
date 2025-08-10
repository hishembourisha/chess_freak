// File: lib/services/chess_engine.dart

import 'dart:math';

enum PieceType { pawn, rook, knight, bishop, queen, king }
enum PieceColor { white, black }
enum GameState { playing, check, checkmate, stalemate, draw }
enum Difficulty { beginner, intermediate, advanced }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  ChessPiece copy() {
    return ChessPiece(
      type: type,
      color: color,
      hasMoved: hasMoved,
    );
  }

  String get symbol {
    const symbols = {
      PieceType.pawn: {'white': '♙', 'black': '♟'},
      PieceType.rook: {'white': '♖', 'black': '♜'},
      PieceType.knight: {'white': '♘', 'black': '♞'},
      PieceType.bishop: {'white': '♗', 'black': '♝'},
      PieceType.queen: {'white': '♕', 'black': '♛'},
      PieceType.king: {'white': '♔', 'black': '♚'},
    };
    return symbols[type]![color.name]!;
  }

  int get value {
    switch (type) {
      case PieceType.pawn: return 1;
      case PieceType.knight: return 3;
      case PieceType.bishop: return 3;
      case PieceType.rook: return 5;
      case PieceType.queen: return 9;
      case PieceType.king: return 100;
    }
  }
}

class ChessMove {
  final int fromRow, fromCol, toRow, toCol;
  final ChessPiece? capturedPiece;
  final bool isEnPassant;
  final bool isCastling;
  final PieceType? promotionPiece;

  ChessMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.capturedPiece,
    this.isEnPassant = false,
    this.isCastling = false,
    this.promotionPiece,
  });
}

class ChessEngine {
  List<List<ChessPiece?>> board = List.generate(8, (_) => List.filled(8, null));
  PieceColor currentPlayer = PieceColor.white;
  GameState gameState = GameState.playing;
  List<ChessPiece> whiteCaptured = [];
  List<ChessPiece> blackCaptured = [];
  List<ChessMove> moveHistory = [];
  Difficulty difficulty = Difficulty.beginner;
  
  ChessMove? lastMove;
  bool whiteKingMoved = false;
  bool blackKingMoved = false;
  bool whiteKingSideRookMoved = false;
  bool whiteQueenSideRookMoved = false;
  bool blackKingSideRookMoved = false;
  bool blackQueenSideRookMoved = false;

  ChessEngine({this.difficulty = Difficulty.beginner}) {
    initializeBoard();
  }

  void initializeBoard() {
    board = List.generate(8, (_) => List.filled(8, null));
    
    for (int col = 0; col < 8; col++) {
      board[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
      board[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
    }
    
    final backPieces = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook
    ];
    
    for (int col = 0; col < 8; col++) {
      board[0][col] = ChessPiece(type: backPieces[col], color: PieceColor.black);
      board[7][col] = ChessPiece(type: backPieces[col], color: PieceColor.white);
    }
    
    currentPlayer = PieceColor.white;
    gameState = GameState.playing;
    whiteCaptured.clear();
    blackCaptured.clear();
    moveHistory.clear();
    
    whiteKingMoved = false;
    blackKingMoved = false;
    whiteKingSideRookMoved = false;
    whiteQueenSideRookMoved = false;
    blackKingSideRookMoved = false;
    blackQueenSideRookMoved = false;
  }

  bool isValidMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!_isInBounds(fromRow, fromCol) || !_isInBounds(toRow, toCol)) {
      return false;
    }
    
    final piece = board[fromRow][fromCol];
    if (piece == null || piece.color != currentPlayer) {
      return false;
    }
    
    final targetPiece = board[toRow][toCol];
    if (targetPiece != null && targetPiece.color == piece.color) {
      return false;
    }
    
    if (!_isPieceMovementValid(piece, fromRow, fromCol, toRow, toCol)) {
      return false;
    }
    
    return !_wouldMoveResultInCheck(fromRow, fromCol, toRow, toCol);
  }

  
  bool makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!isValidMove(fromRow, fromCol, toRow, toCol)) {
      return false;
    }
    
    final piece = board[fromRow][fromCol]!;
    final capturedPiece = board[toRow][toCol];
    
    if (capturedPiece != null) {
      // 🐛 DEBUG: Add logging
      print('🎯 === CAPTURE DEBUG ===');
      print('Capturing: ${capturedPiece.color} ${capturedPiece.type}');
      print('Before capture - White: ${whiteCaptured.length}, Black: ${blackCaptured.length}');
      
      if (capturedPiece.color == PieceColor.white) {
        whiteCaptured.add(capturedPiece);
        print('✅ Added white piece to whiteCaptured');
      } else {
        blackCaptured.add(capturedPiece);
        print('✅ Added black piece to blackCaptured');
      }
      
      print('After capture - White: ${whiteCaptured.length}, Black: ${blackCaptured.length}');
      print('🎯 === CAPTURE DEBUG END ===');
      // 🐛 DEBUG: End logging
    }
    
    // FIXED: Detect castling move
    bool isCastlingMove = false;
    if (piece.type == PieceType.king && (toCol - fromCol).abs() == 2) {
      isCastlingMove = true;
      
      // Move the rook for castling
      if (toCol > fromCol) {
        // King-side castling
        final rook = board[fromRow][7];
        board[fromRow][5] = rook;
        board[fromRow][7] = null;
        if (rook != null) rook.hasMoved = true;
      } else {
        // Queen-side castling
        final rook = board[fromRow][0];
        board[fromRow][3] = rook;
        board[fromRow][0] = null;
        if (rook != null) rook.hasMoved = true;
      }
    }
    
    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;
    piece.hasMoved = true;
    
    _updateSpecialMoveFlags(piece, fromRow, fromCol);
    
    // FIXED: Create move with proper flags
    final move = ChessMove(
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
      capturedPiece: capturedPiece,
      isCastling: isCastlingMove,  // FIXED: Now properly set
    );
    
    moveHistory.add(move);
    lastMove = move;
    
    currentPlayer = currentPlayer == PieceColor.white 
        ? PieceColor.black 
        : PieceColor.white;
    
    _updateGameState();
    
    return true;
  }

  List<List<int>> getValidMoves(int row, int col) {
    final moves = <List<int>>[];
    
    for (int toRow = 0; toRow < 8; toRow++) {
      for (int toCol = 0; toCol < 8; toCol++) {
        if (isValidMove(row, col, toRow, toCol)) {
          moves.add([toRow, toCol]);
        }
      }
    }
    
    return moves;
  }

  ChessMove? getBestMove() {
    final allMoves = _getAllValidMoves(currentPlayer);
    if (allMoves.isEmpty) return null;
    
    switch (difficulty) {
      case Difficulty.beginner:
        return _getBeginnerMove(allMoves);
      case Difficulty.intermediate:
        return _getIntermediateMove(allMoves);
      case Difficulty.advanced:
        return _getAdvancedMove(allMoves);
    }
  }

  ChessMove _getBeginnerMove(List<ChessMove> moves) {
    final captureMoves = moves.where((m) => m.capturedPiece != null).toList();
    
    if (captureMoves.isNotEmpty && Random().nextDouble() < 0.6) {
      return captureMoves[Random().nextInt(captureMoves.length)];
    }
    
    return moves[Random().nextInt(moves.length)];
  }

  ChessMove _getIntermediateMove(List<ChessMove> moves) {
    ChessMove? bestMove;
    int bestScore = -1000;
    
    for (final move in moves) {
      int score = 0;
      
      if (move.capturedPiece != null) {
        score += move.capturedPiece!.value * 10;
      }
      
      if (_isCenterSquare(move.toRow, move.toCol)) {
        score += 5;
      }
      
      score += Random().nextInt(10);
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove ?? moves.first;
  }

  ChessMove _getAdvancedMove(List<ChessMove> moves) {
    ChessMove? bestMove;
    int bestScore = -10000;
    
    for (final move in moves) {
      final score = _evaluateMove(move, 2);
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove ?? moves.first;
  }

  int _evaluateMove(ChessMove move, int depth) {
    int score = 0;
    
    if (move.capturedPiece != null) {
      score += move.capturedPiece!.value * 100;
    }
    
    score += _getPositionValue(move.toRow, move.toCol);
    
    return score;
  }

  bool _isInBounds(int row, int col) {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  bool _isPieceMovementValid(ChessPiece piece, int fromRow, int fromCol, int toRow, int toCol) {
    final deltaRow = toRow - fromRow;
    final deltaCol = toCol - fromCol;
    
    switch (piece.type) {
      case PieceType.pawn:
        return _isPawnMoveValid(piece, fromRow, fromCol, toRow, toCol, deltaRow, deltaCol);
      case PieceType.rook:
        return _isRookMoveValid(fromRow, fromCol, toRow, toCol, deltaRow, deltaCol);
      case PieceType.knight:
        return _isKnightMoveValid(deltaRow, deltaCol);
      case PieceType.bishop:
        return _isBishopMoveValid(fromRow, fromCol, toRow, toCol, deltaRow, deltaCol);
      case PieceType.queen:
        return _isQueenMoveValid(fromRow, fromCol, toRow, toCol, deltaRow, deltaCol);
      case PieceType.king:
        return _isKingMoveValid(deltaRow, deltaCol);
    }
  }

  bool _isPawnMoveValid(ChessPiece piece, int fromRow, int fromCol, int toRow, int toCol, int deltaRow, int deltaCol) {
    final direction = piece.color == PieceColor.white ? -1 : 1;
    final startRow = piece.color == PieceColor.white ? 6 : 1;
    
    if (deltaCol == 0) {
      if (board[toRow][toCol] != null) return false;
      
      if (deltaRow == direction) return true;
      if (fromRow == startRow && deltaRow == 2 * direction) return true;
    }
    
    if (deltaCol.abs() == 1 && deltaRow == direction) {
      return board[toRow][toCol] != null;
    }
    
    return false;
  }

  bool _isRookMoveValid(int fromRow, int fromCol, int toRow, int toCol, int deltaRow, int deltaCol) {
    if (deltaRow != 0 && deltaCol != 0) return false;
    return _isPathClear(fromRow, fromCol, toRow, toCol);
  }

  bool _isKnightMoveValid(int deltaRow, int deltaCol) {
    return (deltaRow.abs() == 2 && deltaCol.abs() == 1) || 
           (deltaRow.abs() == 1 && deltaCol.abs() == 2);
  }

  bool _isBishopMoveValid(int fromRow, int fromCol, int toRow, int toCol, int deltaRow, int deltaCol) {
    if (deltaRow.abs() != deltaCol.abs()) return false;
    return _isPathClear(fromRow, fromCol, toRow, toCol);
  }

  bool _isQueenMoveValid(int fromRow, int fromCol, int toRow, int toCol, int deltaRow, int deltaCol) {
    return _isRookMoveValid(fromRow, fromCol, toRow, toCol, deltaRow, deltaCol) ||
           _isBishopMoveValid(fromRow, fromCol, toRow, toCol, deltaRow, deltaCol);
  }

  bool _isKingMoveValid(int deltaRow, int deltaCol) {
    return deltaRow.abs() <= 1 && deltaCol.abs() <= 1;
  }

  bool _isPathClear(int fromRow, int fromCol, int toRow, int toCol) {
    final deltaRow = toRow - fromRow;
    final deltaCol = toCol - fromCol;
    
    final stepRow = deltaRow == 0 ? 0 : deltaRow > 0 ? 1 : -1;
    final stepCol = deltaCol == 0 ? 0 : deltaCol > 0 ? 1 : -1;
    
    int currentRow = fromRow + stepRow;
    int currentCol = fromCol + stepCol;
    
    while (currentRow != toRow || currentCol != toCol) {
      if (board[currentRow][currentCol] != null) return false;
      currentRow += stepRow;
      currentCol += stepCol;
    }
    
    return true;
  }

  bool _wouldMoveResultInCheck(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = board[fromRow][fromCol]!;
    final originalTarget = board[toRow][toCol];
    
    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;
    
    final inCheck = _isKingInCheck(piece.color);
    
    board[fromRow][fromCol] = piece;
    board[toRow][toCol] = originalTarget;
    
    return inCheck;
  }

  bool _isKingInCheck(PieceColor kingColor) {
    int kingRow = -1, kingCol = -1;
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece?.type == PieceType.king && piece?.color == kingColor) {
          kingRow = row;
          kingCol = col;
          break;
        }
      }
    }
    
    if (kingRow == -1) return false;
    
    final opponentColor = kingColor == PieceColor.white ? PieceColor.black : PieceColor.white;
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece != null && piece.color == opponentColor) {
          if (_isPieceMovementValid(piece, row, col, kingRow, kingCol)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  List<ChessMove> _getAllValidMoves(PieceColor color) {
    final moves = <ChessMove>[];
    
    for (int fromRow = 0; fromRow < 8; fromRow++) {
      for (int fromCol = 0; fromCol < 8; fromCol++) {
        final piece = board[fromRow][fromCol];
        if (piece?.color == color) {
          for (int toRow = 0; toRow < 8; toRow++) {
            for (int toCol = 0; toCol < 8; toCol++) {
              if (isValidMove(fromRow, fromCol, toRow, toCol)) {
                // FIXED: Detect castling in move generation
                bool isCastlingMove = false;
                if (piece!.type == PieceType.king && (toCol - fromCol).abs() == 2) {
                  isCastlingMove = true;
                }
                
                moves.add(ChessMove(
                  fromRow: fromRow,
                  fromCol: fromCol,
                  toRow: toRow,
                  toCol: toCol,
                  capturedPiece: board[toRow][toCol],
                  isCastling: isCastlingMove,  // FIXED: Properly set here too
                ));
              }
            }
          }
        }
      }
    }
    
    return moves;
  }

  void _updateSpecialMoveFlags(ChessPiece piece, int fromRow, int fromCol) {
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        whiteKingMoved = true;
      } else {
        blackKingMoved = true;
      }
    } else if (piece.type == PieceType.rook) {
      if (piece.color == PieceColor.white) {
        if (fromRow == 7 && fromCol == 0) whiteQueenSideRookMoved = true;
        if (fromRow == 7 && fromCol == 7) whiteKingSideRookMoved = true;
      } else {
        if (fromRow == 0 && fromCol == 0) blackQueenSideRookMoved = true;
        if (fromRow == 0 && fromCol == 7) blackKingSideRookMoved = true;
      }
    }
  }


  void _updateGameState() {
    print('🔍 === GAME STATE UPDATE DEBUG ===');
    print('Current player: $currentPlayer');
    
    final isInCheck = _isKingInCheck(currentPlayer);
    print('King in check: $isInCheck');
    
    final allValidMoves = _getAllValidMoves(currentPlayer);
    print('Valid moves count: ${allValidMoves.length}');
    
    if (isInCheck) {
      if (allValidMoves.isEmpty) {
        print('✅ CHECKMATE detected!');
        gameState = GameState.checkmate;
      } else {
        print('⚠️ CHECK detected - ${allValidMoves.length} moves available');
        gameState = GameState.check;
      }
    } else if (allValidMoves.isEmpty) {
      print('🤝 STALEMATE detected!');
      gameState = GameState.stalemate;
    } else {
      print('▶️ Game continues - ${allValidMoves.length} moves available');
      gameState = GameState.playing;
    }
    
    print('Final game state: $gameState');
    print('🔍 === GAME STATE UPDATE END ===');
  }

  bool _isCenterSquare(int row, int col) {
    return (row >= 3 && row <= 4) && (col >= 3 && col <= 4);
  }

  int _getPositionValue(int row, int col) {
    final centerDistance = ((row - 3.5).abs() + (col - 3.5).abs());
    return (10 - centerDistance * 2).round();
  }

  bool get isGameOver => gameState == GameState.checkmate || gameState == GameState.stalemate;
  bool get isCheck => gameState == GameState.check;
  PieceColor? get winner {
    if (gameState == GameState.checkmate) {
      return currentPlayer == PieceColor.white ? PieceColor.black : PieceColor.white;
    }
    return null;
  }
}