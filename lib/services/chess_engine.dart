// lib/services/chess_engine.dart - Pure Stockfish integration (heuristic AI disabled)

import 'dart:math';

enum PieceType { pawn, rook, knight, bishop, queen, king }
enum PieceColor { white, black }
enum GameState { playing, check, checkmate, stalemate, draw }
enum Difficulty { beginner, intermediate, advanced, grandmaster }

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

  // Advanced evaluation values for AI
  int get advancedValue {
    switch (type) {
      case PieceType.pawn: return 100;
      case PieceType.knight: return 320;
      case PieceType.bishop: return 330;
      case PieceType.rook: return 500;
      case PieceType.queen: return 900;
      case PieceType.king: return 20000;
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

  @override
  String toString() {
    return 'Move(${fromRow},${fromCol} -> ${toRow},${toCol}'
        '${isCastling ? " castle" : ""}'
        '${isEnPassant ? " ep" : ""}'
        '${promotionPiece != null ? " =${promotionPiece}" : ""})';
  }
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
  
  // Castling rights
  bool whiteKingMoved = false;
  bool blackKingMoved = false;
  bool whiteKingSideRookMoved = false;
  bool whiteQueenSideRookMoved = false;
  bool blackKingSideRookMoved = false;
  bool blackQueenSideRookMoved = false;
  
  // En passant tracking
  int? enPassantRow;
  int? enPassantCol;
  
  // 50-move rule counter
  int halfmoveClock = 0;

  // STOCKFISH: Flag to indicate we're using external AI
  bool useStockfishOnly = true;

  ChessEngine({this.difficulty = Difficulty.beginner, this.useStockfishOnly = true}) {
    initializeBoard();
  }

  void initializeBoard() {
    board = List.generate(8, (_) => List.filled(8, null));
    
    // Place pawns
    for (int col = 0; col < 8; col++) {
      board[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
      board[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
    }
    
    // Place back pieces
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
    
    // Reset castling rights
    whiteKingMoved = false;
    blackKingMoved = false;
    whiteKingSideRookMoved = false;
    whiteQueenSideRookMoved = false;
    blackKingSideRookMoved = false;
    blackQueenSideRookMoved = false;
    
    // Reset en passant
    enPassantRow = null;
    enPassantCol = null;
    halfmoveClock = 0;
    
    lastMove = null;
  }

  /// Returns [row, col] of the king that is currently in check,
  /// or null if there is no check.
  List<int>? getCheckedKingSquare() {
    if (gameState != GameState.check) return null;

    final kingColor = currentPlayer; // The side to move is the one in check
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final p = board[row][col];
        if (p?.type == PieceType.king && p?.color == kingColor) {
          return [row, col];
        }
      }
    }
    return null;
  }

  // STOCKFISH: Export current position to FEN for Stockfish
  String toFEN() {
    final sb = StringBuffer();
    
    // Board position
    for (int r = 0; r < 8; r++) {
      int empty = 0;
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) { 
            sb.write(empty); 
            empty = 0; 
          }
          String ch;
          switch (p.type) {
            case PieceType.pawn:   ch = 'p'; break;
            case PieceType.knight: ch = 'n'; break;
            case PieceType.bishop: ch = 'b'; break;
            case PieceType.rook:   ch = 'r'; break;
            case PieceType.queen:  ch = 'q'; break;
            case PieceType.king:   ch = 'k'; break;
          }
          sb.write(p.color == PieceColor.white ? ch.toUpperCase() : ch);
        }
      }
      if (empty > 0) sb.write(empty);
      if (r != 7) sb.write('/');
    }

    // Active color
    final side = currentPlayer == PieceColor.white ? 'w' : 'b';

    // Castling rights
    String rights = '';
    bool _hasPiece(int r, int c, PieceType t, PieceColor col) {
      final p = board[r][c];
      return p != null && p.type == t && p.color == col;
    }
    
    if (!whiteKingMoved && !whiteKingSideRookMoved && 
        _hasPiece(7, 7, PieceType.rook, PieceColor.white)) {
      rights += 'K';
    }
    if (!whiteKingMoved && !whiteQueenSideRookMoved && 
        _hasPiece(7, 0, PieceType.rook, PieceColor.white)) {
      rights += 'Q';
    }
    if (!blackKingMoved && !blackKingSideRookMoved && 
        _hasPiece(0, 7, PieceType.rook, PieceColor.black)) {
      rights += 'k';
    }
    if (!blackKingMoved && !blackQueenSideRookMoved && 
        _hasPiece(0, 0, PieceType.rook, PieceColor.black)) {
      rights += 'q';
    }
    if (rights.isEmpty) rights = '-';

    // En passant target
    String ep;
    if (enPassantRow != null && enPassantCol != null) {
      final file = String.fromCharCode('a'.codeUnitAt(0) + enPassantCol!);
      final rank = (8 - enPassantRow!).toString();
      ep = '$file$rank';
    } else {
      ep = '-';
    }

    // Halfmove and fullmove counters
    final half = halfmoveClock;
    final full = (moveHistory.length ~/ 2) + 1;

    return '${sb.toString()} $side $rights $ep $half $full';
  }

  // STOCKFISH: Apply a UCI move from Stockfish
  bool applyUCIMove(String uci) {
    if (uci.length < 4) return false;
    
    int _fileToCol(String f) => f.codeUnitAt(0) - 'a'.codeUnitAt(0);
    int _rankToRow(int r) => 8 - r;

    final fromFile = uci[0];
    final fromRank = int.parse(uci[1]);
    final toFile   = uci[2];
    final toRank   = int.parse(uci[3]);

    final fromCol = _fileToCol(fromFile);
    final fromRow = _rankToRow(fromRank);
    final toCol   = _fileToCol(toFile);
    final toRow   = _rankToRow(toRank);

    print('🔄 Applying UCI move: $uci -> ($fromRow,$fromCol) to ($toRow,$toCol)');

    // Handle promotion if present
    PieceType? promotionType;
    if (uci.length == 5) {
      switch (uci[4].toLowerCase()) {
        case 'q': promotionType = PieceType.queen; break;
        case 'r': promotionType = PieceType.rook; break;
        case 'b': promotionType = PieceType.bishop; break;
        case 'n': promotionType = PieceType.knight; break;
      }
      print('🤴 Promotion detected: ${uci[4]} -> $promotionType');
    }

    // Validate bounds
    if (fromRow < 0 || fromRow > 7 || fromCol < 0 || fromCol > 7 ||
        toRow < 0 || toRow > 7 || toCol < 0 || toCol > 7) {
      print('❌ UCI move out of bounds: $uci');
      return false;
    }

    // Apply the move using existing makeMove logic
    final success = makeMove(fromRow, fromCol, toRow, toCol);
    
    if (success && promotionType != null) {
      // Handle promotion after the move
      board[toRow][toCol] = ChessPiece(
        type: promotionType,
        color: currentPlayer == PieceColor.white ? PieceColor.black : PieceColor.white,
        hasMoved: true,
      );
      print('✅ Promotion applied: $promotionType');
    }
    
    return success;
  }

  bool isValidMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!_inBounds(fromRow, fromCol) || !_inBounds(toRow, toCol)) {
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
    
    // Check if it's a castling attempt
    if (_isCastlingAttempt(piece, fromRow, fromCol, toRow, toCol)) {
      return _canCastle(piece.color, fromRow, toCol > fromCol);
    }
    
    // Check piece-specific movement rules
    if (!_isPieceMovementValid(piece, fromRow, fromCol, toRow, toCol)) {
      return false;
    }
    
    // Check if move would leave own king in check
    return !_wouldMoveResultInCheck(fromRow, fromCol, toRow, toCol);
  }

  bool makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!isValidMove(fromRow, fromCol, toRow, toCol)) {
      return false;
    }
    
    final piece = board[fromRow][fromCol]!;
    final capturedPiece = board[toRow][toCol];
    
    // Handle normal captures
    if (capturedPiece != null) {
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
    }
    
    // Handle en passant capture
    ChessPiece? enPassantCaptured;
    bool isEnPassant = false;
    if (_isEnPassantMove(piece, fromRow, fromCol, toRow, toCol)) {
      final dir = piece.color == PieceColor.white ? 1 : -1;
      enPassantCaptured = board[toRow + dir][toCol];
      board[toRow + dir][toCol] = null;
      isEnPassant = true;
      
      if (enPassantCaptured != null) {
        if (enPassantCaptured.color == PieceColor.white) {
          whiteCaptured.add(enPassantCaptured);
        } else {
          blackCaptured.add(enPassantCaptured);
        }
        print('🎯 En passant capture: ${enPassantCaptured.color} ${enPassantCaptured.type}');
      }
    }
    
    // Handle castling
    bool isCastlingMove = false;
    if (piece.type == PieceType.king && (toCol - fromCol).abs() == 2) {
      isCastlingMove = true;
      
      if (toCol > fromCol) {
        // King-side castling
        final rook = board[fromRow][7];
        board[fromRow][5] = rook;
        board[fromRow][7] = null;
        if (rook != null) rook.hasMoved = true;
        print('🏰 King-side castling completed');
      } else {
        // Queen-side castling
        final rook = board[fromRow][0];
        board[fromRow][3] = rook;
        board[fromRow][0] = null;
        if (rook != null) rook.hasMoved = true;
        print('🏰 Queen-side castling completed');
      }
    }
    
    // Reset en passant
    enPassantRow = null;
    enPassantCol = null;
    
    // Update halfmove clock
    if (piece.type == PieceType.pawn || capturedPiece != null || enPassantCaptured != null) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }
    
    // Check for pawn promotion
    PieceType? promotionPiece;
    bool isPawnPromotion = false;
    
    if (piece.type == PieceType.pawn) {
      if ((piece.color == PieceColor.white && toRow == 0) ||
          (piece.color == PieceColor.black && toRow == 7)) {
        isPawnPromotion = true;
        promotionPiece = PieceType.queen; // Always promote to queen for simplicity
      }
    }
    
    // Move the piece
    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;
    piece.hasMoved = true;
    
    // Handle promotion
    if (isPawnPromotion && promotionPiece != null) {
      board[toRow][toCol] = ChessPiece(
        type: promotionPiece,
        color: piece.color,
        hasMoved: true,
      );
      print('👑 PAWN PROMOTION: ${piece.color} pawn promoted to $promotionPiece at row $toRow, col $toCol');
    }
    
    // Update castling rights
    _updateCastlingRights(piece, fromRow, fromCol, capturedPiece, toRow, toCol);
    
    // Set en passant target if pawn moved two squares
    if (piece.type == PieceType.pawn && (toRow - fromRow).abs() == 2) {
      enPassantRow = (fromRow + toRow) ~/ 2;
      enPassantCol = fromCol;
      print('🚀 En passant target set at $enPassantRow, $enPassantCol');
    }
    
    // Create the move record
    final move = ChessMove(
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
      capturedPiece: capturedPiece ?? enPassantCaptured,
      isCastling: isCastlingMove,
      isEnPassant: isEnPassant,
      promotionPiece: promotionPiece,
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

  // DISABLED: Heuristic AI methods when using Stockfish
  ChessMove? getBestMove() {
    if (useStockfishOnly) {
      print('🚫 getBestMove() called but useStockfishOnly=true - returning null');
      return null; // Force use of Stockfish only
    }
    
    // Legacy heuristic AI code (kept for fallback but disabled by default)
    final allMoves = _getAllValidMoves(currentPlayer);
    if (allMoves.isEmpty) return null;
    
    switch (difficulty) {
      case Difficulty.beginner:
        return _getBeginnerMove(allMoves);
      case Difficulty.intermediate:
        return _getIntermediateMove(allMoves);
      case Difficulty.advanced:
      case Difficulty.grandmaster:
        return _getAdvancedMove(allMoves);
    }
  }

  // LEGACY: Heuristic AI methods (disabled when useStockfishOnly=true)
  ChessMove _getBeginnerMove(List<ChessMove> moves) {
    // Simple strategy: prefer captures, otherwise random
    final captureMoves = moves.where((m) => m.capturedPiece != null).toList();
    final promotionMoves = moves.where((m) => m.promotionPiece != null).toList();
    
    // Strongly prefer promotions
    if (promotionMoves.isNotEmpty && Random().nextDouble() < 0.9) {
      return promotionMoves[Random().nextInt(promotionMoves.length)];
    }
    
    // Then prefer captures
    if (captureMoves.isNotEmpty && Random().nextDouble() < 0.6) {
      return captureMoves[Random().nextInt(captureMoves.length)];
    }
    
    return moves[Random().nextInt(moves.length)];
  }

  ChessMove _getIntermediateMove(List<ChessMove> moves) {
    ChessMove? bestMove;
    int bestScore = -10000;
    
    for (final move in moves) {
      int score = 0;
      
      // Heavily prioritize captures based on piece value
      if (move.capturedPiece != null) {
        score += move.capturedPiece!.value * 30;
      }
      
      // Very high priority for promotions
      if (move.promotionPiece != null) {
        score += 300;
      }
      
      // Encourage center control
      if (_isCenterSquare(move.toRow, move.toCol)) {
        score += 15;
      }
      
      // Encourage piece development (moving from back rank)
      final piece = board[move.fromRow][move.fromCol];
      if (piece != null && piece.color == currentPlayer) {
        if ((piece.color == PieceColor.white && move.fromRow == 7) ||
            (piece.color == PieceColor.black && move.fromRow == 0)) {
          if (piece.type != PieceType.pawn && piece.type != PieceType.king) {
            score += 8;
          }
        }
      }
      
      // Add position value
      score += _getPositionValue(move.toRow, move.toCol);
      
      // Small random factor
      score += Random().nextInt(3);
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    
    return bestMove ?? moves.first;
  }

  ChessMove _getAdvancedMove(List<ChessMove> moves) {
    // Use minimax with alpha-beta pruning
    const depth = 3;
    
    moves.sort(_orderMoves);
    
    int alpha = -999999;
    int beta = 999999;
    ChessMove? bestMove;
    int bestScore = -999999;
    
    for (final move in moves) {
      final boardCopy = _copyBoard();
      final stateCopy = _copyGameState();
      
      _makeTemporaryMove(move);
      final score = -_negamax(depth - 1, -beta, -alpha, _getOppositeColor(currentPlayer));
      
      _restoreBoard(boardCopy);
      _restoreGameState(stateCopy);
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      
      if (score > alpha) {
        alpha = score;
      }
      
      if (alpha >= beta) {
        break; // Alpha-beta pruning
      }
    }
    
    return bestMove ?? moves.first;
  }

  // Helper methods
  bool _inBounds(int row, int col) {
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
    
    // Forward movement
    if (deltaCol == 0) {
      if (board[toRow][toCol] != null) return false;
      
      // One step forward
      if (deltaRow == direction) return true;
      
      // Two steps forward from starting position
      if (fromRow == startRow && deltaRow == 2 * direction) {
        return board[fromRow + direction][fromCol] == null;
      }
    }
    
    // Diagonal capture
    if (deltaCol.abs() == 1 && deltaRow == direction) {
      // Normal capture
      if (board[toRow][toCol] != null && board[toRow][toCol]!.color != piece.color) {
        return true;
      }
      
      // En passant capture
      if (_isEnPassantMove(piece, fromRow, fromCol, toRow, toCol)) {
        return true;
      }
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

  bool _isCastlingAttempt(ChessPiece piece, int fromRow, int fromCol, int toRow, int toCol) {
    return piece.type == PieceType.king && fromRow == toRow && (toCol - fromCol).abs() == 2;
  }

  bool _canCastle(PieceColor color, int row, bool kingSide) {
    // Check if king or rook has moved
    if (color == PieceColor.white) {
      if (whiteKingMoved) return false;
      if (kingSide && whiteKingSideRookMoved) return false;
      if (!kingSide && whiteQueenSideRookMoved) return false;
    } else {
      if (blackKingMoved) return false;
      if (kingSide && blackKingSideRookMoved) return false;
      if (!kingSide && blackQueenSideRookMoved) return false;
    }
    
    // Check if path is clear
    final pathCols = kingSide ? [5, 6] : [1, 2, 3];
    for (final col in pathCols) {
      if (board[row][col] != null) return false;
    }
    
    // Check if rook exists
    final rookCol = kingSide ? 7 : 0;
    final rook = board[row][rookCol];
    if (rook == null || rook.type != PieceType.rook || rook.color != color) {
      return false;
    }
    
    // Check if king is in check or would pass through check
    if (_isKingInCheck(color)) return false;
    if (_isSquareAttacked(row, kingSide ? 5 : 3, color)) return false;
    if (_isSquareAttacked(row, kingSide ? 6 : 2, color)) return false;
    
    return true;
  }

  bool _isEnPassantMove(ChessPiece piece, int fromRow, int fromCol, int toRow, int toCol) {
    if (piece.type != PieceType.pawn) return false;
    if (enPassantRow == null || enPassantCol == null) return false;
    
    return toRow == enPassantRow && toCol == enPassantCol && (toCol - fromCol).abs() == 1;
  }

  bool _wouldMoveResultInCheck(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = board[fromRow][fromCol]!;
    final originalTarget = board[toRow][toCol];
    
    // Handle en passant capture for simulation
    ChessPiece? enPassantCaptured;
    if (_isEnPassantMove(piece, fromRow, fromCol, toRow, toCol)) {
      final dir = piece.color == PieceColor.white ? 1 : -1;
      enPassantCaptured = board[toRow + dir][toCol];
      board[toRow + dir][toCol] = null;
    }
    
    // Simulate the move
    ChessPiece pieceToPlace = piece;
    if (piece.type == PieceType.pawn) {
      if ((piece.color == PieceColor.white && toRow == 0) ||
          (piece.color == PieceColor.black && toRow == 7)) {
        pieceToPlace = ChessPiece(
          type: PieceType.queen,
          color: piece.color,
          hasMoved: true,
        );
      }
    }
    
    board[toRow][toCol] = pieceToPlace;
    board[fromRow][fromCol] = null;
    
    final inCheck = _isKingInCheck(piece.color);
    
    // Restore the board
    board[fromRow][fromCol] = piece;
    board[toRow][toCol] = originalTarget;
    if (enPassantCaptured != null) {
      final dir = piece.color == PieceColor.white ? 1 : -1;
      board[toRow + dir][toCol] = enPassantCaptured;
    }
    
    return inCheck;
  }

  bool _isKingInCheck(PieceColor kingColor) {
    int kingRow = -1, kingCol = -1;
    
    // Find the king
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece?.type == PieceType.king && piece?.color == kingColor) {
          kingRow = row;
          kingCol = col;
          break;
        }
      }
      if (kingRow != -1) break;
    }
    
    if (kingRow == -1) return false;
    
    return _isSquareAttacked(kingRow, kingCol, kingColor);
  }

  bool _isSquareAttacked(int row, int col, PieceColor byColor) {
    final opponentColor = byColor == PieceColor.white ? PieceColor.black : PieceColor.white;
    
    // Check all opponent pieces to see if they can attack this square
    for (int fromRow = 0; fromRow < 8; fromRow++) {
      for (int fromCol = 0; fromCol < 8; fromCol++) {
        final piece = board[fromRow][fromCol];
        if (piece == null || piece.color != opponentColor) continue;
        
        if (_canPieceAttackSquare(piece, fromRow, fromCol, row, col)) {
          return true;
        }
      }
    }
    
    return false;
  }

  bool _canPieceAttackSquare(ChessPiece piece, int fromRow, int fromCol, int toRow, int toCol) {
    final deltaRow = toRow - fromRow;
    final deltaCol = toCol - fromCol;
    
    switch (piece.type) {
      case PieceType.pawn:
        final direction = piece.color == PieceColor.white ? -1 : 1;
        return deltaRow == direction && deltaCol.abs() == 1;
      
      case PieceType.rook:
        if (deltaRow != 0 && deltaCol != 0) return false;
        return _isPathClear(fromRow, fromCol, toRow, toCol);
      
      case PieceType.knight:
        return (deltaRow.abs() == 2 && deltaCol.abs() == 1) ||
               (deltaRow.abs() == 1 && deltaCol.abs() == 2);
      
      case PieceType.bishop:
        if (deltaRow.abs() != deltaCol.abs()) return false;
        return _isPathClear(fromRow, fromCol, toRow, toCol);
      
      case PieceType.queen:
        if (deltaRow == 0 || deltaCol == 0 || deltaRow.abs() == deltaCol.abs()) {
          return _isPathClear(fromRow, fromCol, toRow, toCol);
        }
        return false;
      
      case PieceType.king:
        return deltaRow.abs() <= 1 && deltaCol.abs() <= 1;
    }
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
                final move = ChessMove(
                  fromRow: fromRow,
                  fromCol: fromCol,
                  toRow: toRow,
                  toCol: toCol,
                  capturedPiece: _getCapturedPiece(fromRow, fromCol, toRow, toCol),
                  isEnPassant: _isEnPassantMove(piece!, fromRow, fromCol, toRow, toCol),
                  isCastling: _isCastlingAttempt(piece, fromRow, fromCol, toRow, toCol),
                  promotionPiece: _needsPromotion(piece, toRow) ? PieceType.queen : null,
                );
                moves.add(move);
              }
            }
          }
        }
      }
    }
    
    return moves;
  }

  ChessPiece? _getCapturedPiece(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = board[fromRow][fromCol];
    if (piece == null) return null;
    
    // En passant capture
    if (_isEnPassantMove(piece, fromRow, fromCol, toRow, toCol)) {
      final dir = piece.color == PieceColor.white ? 1 : -1;
      return board[toRow + dir][toCol];
    }
    
    // Normal capture
    return board[toRow][toCol];
  }

  bool _needsPromotion(ChessPiece piece, int toRow) {
    return piece.type == PieceType.pawn &&
           ((piece.color == PieceColor.white && toRow == 0) ||
            (piece.color == PieceColor.black && toRow == 7));
  }

  void _updateCastlingRights(ChessPiece piece, int fromRow, int fromCol, ChessPiece? capturedPiece, int toRow, int toCol) {
    // Update rights when king moves
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        whiteKingMoved = true;
      } else {
        blackKingMoved = true;
      }
    }
    
    // Update rights when rook moves
    if (piece.type == PieceType.rook) {
      if (piece.color == PieceColor.white) {
        if (fromRow == 7 && fromCol == 0) whiteQueenSideRookMoved = true;
        if (fromRow == 7 && fromCol == 7) whiteKingSideRookMoved = true;
      } else {
        if (fromRow == 0 && fromCol == 0) blackQueenSideRookMoved = true;
        if (fromRow == 0 && fromCol == 7) blackKingSideRookMoved = true;
      }
    }
    
    // Update rights when rook is captured
    if (capturedPiece != null && capturedPiece.type == PieceType.rook) {
      if (capturedPiece.color == PieceColor.white) {
        if (toRow == 7 && toCol == 0) whiteQueenSideRookMoved = true;
        if (toRow == 7 && toCol == 7) whiteKingSideRookMoved = true;
      } else {
        if (toRow == 0 && toCol == 0) blackQueenSideRookMoved = true;
        if (toRow == 0 && toCol == 7) blackKingSideRookMoved = true;
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
    } else if (halfmoveClock >= 100) {
      print('📋 50-MOVE RULE draw!');
      gameState = GameState.draw;
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

  // LEGACY: Board manipulation for AI search (kept for compatibility)
  List<List<ChessPiece?>> _copyBoard() {
    return board.map((row) => 
      row.map((piece) => piece?.copy()).toList()
    ).toList();
  }

  _GameState _copyGameState() {
    return _GameState(
      currentPlayer: currentPlayer,
      gameState: gameState,
      whiteKingMoved: whiteKingMoved,
      blackKingMoved: blackKingMoved,
      whiteKingSideRookMoved: whiteKingSideRookMoved,
      whiteQueenSideRookMoved: whiteQueenSideRookMoved,
      blackKingSideRookMoved: blackKingSideRookMoved,
      blackQueenSideRookMoved: blackQueenSideRookMoved,
      enPassantRow: enPassantRow,
      enPassantCol: enPassantCol,
      halfmoveClock: halfmoveClock,
    );
  }

  void _restoreBoard(List<List<ChessPiece?>> boardCopy) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        board[row][col] = boardCopy[row][col]?.copy();
      }
    }
  }

  void _restoreGameState(_GameState state) {
    currentPlayer = state.currentPlayer;
    gameState = state.gameState;
    whiteKingMoved = state.whiteKingMoved;
    blackKingMoved = state.blackKingMoved;
    whiteKingSideRookMoved = state.whiteKingSideRookMoved;
    whiteQueenSideRookMoved = state.whiteQueenSideRookMoved;
    blackKingSideRookMoved = state.blackKingSideRookMoved;
    blackQueenSideRookMoved = state.blackQueenSideRookMoved;
    enPassantRow = state.enPassantRow;
    enPassantCol = state.enPassantCol;
    halfmoveClock = state.halfmoveClock;
  }

  void _makeTemporaryMove(ChessMove move) {
    final piece = board[move.fromRow][move.fromCol]!;
    
    // Handle en passant capture
    if (move.isEnPassant) {
      final dir = piece.color == PieceColor.white ? 1 : -1;
      board[move.toRow + dir][move.toCol] = null;
    }
    
    // Make the move
    board[move.toRow][move.toCol] = piece;
    board[move.fromRow][move.fromCol] = null;
    
    // Handle promotion
    if (move.promotionPiece != null) {
      board[move.toRow][move.toCol] = ChessPiece(
        type: move.promotionPiece!,
        color: piece.color,
        hasMoved: true,
      );
    }
    
    // Handle castling
    if (move.isCastling) {
      final isKingSide = move.toCol > move.fromCol;
      final rookFromCol = isKingSide ? 7 : 0;
      final rookToCol = isKingSide ? 5 : 3;
      final rook = board[move.fromRow][rookFromCol];
      board[move.fromRow][rookToCol] = rook;
      board[move.fromRow][rookFromCol] = null;
    }
    
    // Update state
    piece.hasMoved = true;
    _updateCastlingRights(piece, move.fromRow, move.fromCol, move.capturedPiece, move.toRow, move.toCol);
    
    // Update en passant
    enPassantRow = null;
    enPassantCol = null;
    if (piece.type == PieceType.pawn && (move.toRow - move.fromRow).abs() == 2) {
      enPassantRow = (move.fromRow + move.toRow) ~/ 2;
      enPassantCol = move.fromCol;
    }
    
    // Update halfmove clock
    if (piece.type == PieceType.pawn || move.capturedPiece != null) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }
    
    currentPlayer = _getOppositeColor(currentPlayer);
  }

  int _negamax(int depth, int alpha, int beta, PieceColor sideToMove) {
    if (depth == 0) return _evaluate(sideToMove);
    
    final moves = _getAllValidMoves(sideToMove);
    if (moves.isEmpty) {
      if (_isKingInCheck(sideToMove)) {
        return -100000; // Checkmate
      }
      return 0; // Stalemate
    }
    
    moves.sort(_orderMoves);
    
    int bestScore = -999999;
    for (final move in moves) {
      final boardCopy = _copyBoard();
      final stateCopy = _copyGameState();
      
      _makeTemporaryMove(move);
      final score = -_negamax(depth - 1, -beta, -alpha, _getOppositeColor(sideToMove));
      
      _restoreBoard(boardCopy);
      _restoreGameState(stateCopy);
      
      if (score > bestScore) {
        bestScore = score;
      }
      if (bestScore > alpha) {
        alpha = bestScore;
      }
      if (alpha >= beta) {
        break; // Alpha-beta pruning
      }
    }
    
    return bestScore;
  }

  int _orderMoves(ChessMove a, ChessMove b) {
    int scoreA = 0;
    int scoreB = 0;
    
    // Prioritize captures (MVV-LVA: Most Valuable Victim - Least Valuable Attacker)
    if (a.capturedPiece != null) {
      scoreA += a.capturedPiece!.advancedValue + 5000;
      final attacker = board[a.fromRow][a.fromCol];
      if (attacker != null) {
        scoreA -= attacker.advancedValue ~/ 10;
      }
    }
    if (b.capturedPiece != null) {
      scoreB += b.capturedPiece!.advancedValue + 5000;
      final attacker = board[b.fromRow][b.fromCol];
      if (attacker != null) {
        scoreB -= attacker.advancedValue ~/ 10;
      }
    }
    
    // Prioritize promotions
    if (a.promotionPiece != null) scoreA += 4000;
    if (b.promotionPiece != null) scoreB += 4000;
    
    // Prioritize checks (simplified: moves that attack opponent king area)
    if (_moveGivesCheck(a)) scoreA += 100;
    if (_moveGivesCheck(b)) scoreB += 100;
    
    // Prioritize center moves
    scoreA += _getPositionValue(a.toRow, a.toCol);
    scoreB += _getPositionValue(b.toRow, b.toCol);
    
    return scoreB - scoreA;
  }

  bool _moveGivesCheck(ChessMove move) {
    // Simple check detection: would this move attack the opponent king?
    final piece = board[move.fromRow][move.fromCol];
    if (piece == null) return false;
    
    final opponentColor = _getOppositeColor(piece.color);
    
    // Find opponent king
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final target = board[row][col];
        if (target?.type == PieceType.king && target?.color == opponentColor) {
          // Would our piece attack the king from its new position?
          return _canPieceAttackSquare(piece, move.toRow, move.toCol, row, col);
        }
      }
    }
    return false;
  }

  int _evaluate(PieceColor sideToMove) {
    int score = 0;
    
    // Material evaluation with position bonuses
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == null) continue;
        
        int pieceValue = piece.advancedValue + _getPieceSquareValue(piece, row, col);
        
        if (piece.color == PieceColor.white) {
          score += pieceValue;
        } else {
          score -= pieceValue;
        }
      }
    }
    
    // Mobility bonus (number of legal moves)
    final whiteMoves = _getAllValidMoves(PieceColor.white).length;
    final blackMoves = _getAllValidMoves(PieceColor.black).length;
    score += (whiteMoves - blackMoves) * 3;
    
    // King safety penalty if in check
    if (_isKingInCheck(PieceColor.white)) score -= 50;
    if (_isKingInCheck(PieceColor.black)) score += 50;
    
    // Encourage castling rights
    if (!whiteKingMoved) score += 20;
    if (!blackKingMoved) score -= 20;
    
    // Return score from perspective of sideToMove
    return sideToMove == PieceColor.white ? score : -score;
  }

  int _getPieceSquareValue(ChessPiece piece, int row, int col) {
    final centerBonus = _getPositionValue(row, col);
    
    switch (piece.type) {
      case PieceType.pawn:
        // Encourage pawn advancement
        final advancement = piece.color == PieceColor.white ? (6 - row) : (row - 1);
        return advancement * 5 + centerBonus ~/ 3;
      
      case PieceType.knight:
        // Knights are better in the center
        return centerBonus * 2;
      
      case PieceType.bishop:
        // Bishops prefer long diagonals
        return centerBonus + 8;
      
      case PieceType.rook:
        // Rooks prefer open files and 7th rank
        int bonus = 0;
        if (piece.color == PieceColor.white && row == 1) bonus += 15;
        if (piece.color == PieceColor.black && row == 6) bonus += 15;
        return bonus + centerBonus ~/ 2;
      
      case PieceType.queen:
        // Queen prefers central squares but not too early
        return centerBonus ~/ 3;
      
      case PieceType.king:
        // King safety - prefer corners in opening/middlegame
        final endgame = _isEndgame();
        return endgame ? centerBonus : -centerBonus;
    }
  }

  bool _isEndgame() {
    // Simple endgame detection: few pieces left
    int pieceCount = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if (board[row][col] != null) pieceCount++;
      }
    }
    return pieceCount <= 12; // Endgame when 12 or fewer pieces
  }

  PieceColor _getOppositeColor(PieceColor color) {
    return color == PieceColor.white ? PieceColor.black : PieceColor.white;
  }

  // Public getters for compatibility
  bool get isGameOver => gameState == GameState.checkmate || 
                        gameState == GameState.stalemate || 
                        gameState == GameState.draw;
  bool get isCheck => gameState == GameState.check;
  
  PieceColor? get winner {
    if (gameState == GameState.checkmate) {
      return currentPlayer == PieceColor.white ? PieceColor.black : PieceColor.white;
    }
    return null;
  }
}

// Helper class for game state copying during AI search
class _GameState {
  final PieceColor currentPlayer;
  final GameState gameState;
  final bool whiteKingMoved;
  final bool blackKingMoved;
  final bool whiteKingSideRookMoved;
  final bool whiteQueenSideRookMoved;
  final bool blackKingSideRookMoved;
  final bool blackQueenSideRookMoved;
  final int? enPassantRow;
  final int? enPassantCol;
  final int halfmoveClock;

  _GameState({
    required this.currentPlayer,
    required this.gameState,
    required this.whiteKingMoved,
    required this.blackKingMoved,
    required this.whiteKingSideRookMoved,
    required this.whiteQueenSideRookMoved,
    required this.blackKingSideRookMoved,
    required this.blackQueenSideRookMoved,
    required this.enPassantRow,
    required this.enPassantCol,
    required this.halfmoveClock,
  });
}