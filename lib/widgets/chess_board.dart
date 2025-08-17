// File: lib/widgets/chess_board.dart - Pure Stockfish version (no heuristic AI)

import 'package:flutter/material.dart';
import '../services/chess_engine.dart';

class ChessBoardWidget extends StatefulWidget {
  final ChessEngine engine;
  final Function(ChessMove)? onMoveMade;
  final bool isPlayerWhite;
  final bool useStockfish; // NEW: Flag to disable heuristic AI

  const ChessBoardWidget({
    super.key,
    required this.engine,
    this.onMoveMade,
    this.isPlayerWhite = true,
    this.useStockfish = true, // NEW: Default to Stockfish only
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with TickerProviderStateMixin {
  int? selectedRow;
  int? selectedCol;
  List<List<int>> validMoves = [];
  
  // Game end visualization - STABLE state management
  bool isShowingGameEndVisualization = false;
  Set<String> highlightedSquares = {}; // Store "row,col" strings
  
  // OPTIMIZED: Fewer animation controllers to reduce conflicts
  late AnimationController _pieceAnimationController; // Combined for moves and captures
  late AnimationController _gameEndAnimationController; // For game end highlighting
  
  // STABILITY: Cache the last known board state to prevent unnecessary rebuilds
  List<List<ChessPiece?>>? _lastBoardState;
  GameState? _lastGameState;
  
  @override
  void initState() {
    super.initState();
    
    // OPTIMIZED: Single animation controller for piece movements
    _pieceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Slightly faster
      vsync: this,
    );
    
    // Game end visualization controller
    _gameEndAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize cache
    _lastBoardState = _copyBoard(widget.engine.board);
    _lastGameState = widget.engine.gameState;
    
    // REMOVED: No auto AI move checking - let game_screen.dart handle it
  }

  @override
  void dispose() {
    _pieceAnimationController.dispose();
    _gameEndAnimationController.dispose();
    super.dispose();
  }

  // HELPER: Deep copy board state for comparison
  List<List<ChessPiece?>> _copyBoard(List<List<ChessPiece?>> board) {
    return board.map((row) => 
      row.map((piece) => piece?.copy()).toList()
    ).toList();
  }

  // STABILITY: Only update if board actually changed
  @override
  void didUpdateWidget(ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if board state actually changed to avoid unnecessary rebuilds
    final currentBoard = widget.engine.board;
    final currentGameState = widget.engine.gameState;
    
    bool boardChanged = false;
    if (_lastBoardState == null) {
      boardChanged = true;
    } else {
      // Compare board states
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          final lastPiece = _lastBoardState![row][col];
          final currentPiece = currentBoard[row][col];
          
          if ((lastPiece == null) != (currentPiece == null)) {
            boardChanged = true;
            break;
          }
          
          if (lastPiece != null && currentPiece != null) {
            if (lastPiece.type != currentPiece.type || 
                lastPiece.color != currentPiece.color ||
                lastPiece.hasMoved != currentPiece.hasMoved) {
              boardChanged = true;
              break;
            }
          }
        }
        if (boardChanged) break;
      }
    }
    
    // Only trigger updates if something actually changed
    if (boardChanged || _lastGameState != currentGameState) {
      _lastBoardState = _copyBoard(currentBoard);
      _lastGameState = currentGameState;
      
      // REMOVED: No auto AI move checking - pure view widget now
    }
  }

  // Method to find king position
  Map<String, int>? _findKingPosition(PieceColor color) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = widget.engine.board[row][col];
        if (piece?.type == PieceType.king && piece?.color == color) {
          return {'row': row, 'col': col};
        }
      }
    }
    return null;
  }

  // Method to get squares adjacent to king
  Set<String> _getAdjacentSquares(int kingRow, int kingCol) {
    final adjacentSquares = <String>{};
    
    // All 8 directions around the king
    final directions = [
      [-1, -1], [-1, 0], [-1, 1],  // Top row
      [0, -1],           [0, 1],   // Middle row (excluding king's position)
      [1, -1],  [1, 0],  [1, 1],   // Bottom row
    ];
    
    for (final direction in directions) {
      final newRow = kingRow + direction[0];
      final newCol = kingCol + direction[1];
      
      // Check if the square is within bounds
      if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
        adjacentSquares.add('$newRow,$newCol');
      }
    }
    
    return adjacentSquares;
  }

  // SMOOTH: Start game end visualization without causing layout shifts
  Future<void> startGameEndVisualization() async {
    if (widget.engine.gameState != GameState.checkmate && 
        widget.engine.gameState != GameState.stalemate) {
      return;
    }

    print('🎨 === GAME END VISUALIZATION START ===');
    print('Game state: ${widget.engine.gameState}');
    
    // Find the current player's king (the one who is in checkmate/stalemate)
    final kingPosition = _findKingPosition(widget.engine.currentPlayer);
    
    if (kingPosition == null) {
      print('⚠️ Could not find king position for visualization');
      return;
    }
    
    final kingRow = kingPosition['row']!;
    final kingCol = kingPosition['col']!;
    
    print('👑 King found at: row $kingRow, col $kingCol');
    
    // Get all squares adjacent to the king
    final adjacentSquares = _getAdjacentSquares(kingRow, kingCol);
    
    print('🔍 Adjacent squares: $adjacentSquares');
    
    // SMOOTH: Update state only once and avoid layout thrashing
    if (mounted) {
      setState(() {
        isShowingGameEndVisualization = true;
        highlightedSquares = adjacentSquares;
      });
      
      // Start the animation (pulsing effect)
      _gameEndAnimationController.repeat(reverse: true);
    }
    
    print('✅ Game end visualization started');
    print('🎨 === GAME END VISUALIZATION END ===');
    
    // Wait 3 seconds before allowing the game over dialog to show
    await Future.delayed(const Duration(seconds: 3));
    
    // SMOOTH: Clean stop without jarring state changes
    if (mounted) {
      _gameEndAnimationController.stop();
      setState(() {
        isShowingGameEndVisualization = false;
        highlightedSquares.clear();
      });
    }
  }

  // REMOVED: _checkForAIMove and _makeAIMove methods
  // The game screen now handles all AI logic through Stockfish

  void _onSquareTapped(int row, int col) {
    // STABILITY: Prevent interactions during animations or game over
    if (widget.engine.isGameOver || isShowingGameEndVisualization) return;

    final isPlayerTurn = (widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.white) ||
                        (!widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.black);
    
    if (!isPlayerTurn) return;

    // SMOOTH: Batch state updates to reduce rebuilds
    setState(() {
      if (selectedRow == null || selectedCol == null) {
        final piece = widget.engine.board[row][col];
        if (piece != null && piece.color == widget.engine.currentPlayer) {
          selectedRow = row;
          selectedCol = col;
          validMoves = widget.engine.getValidMoves(row, col);
        }
      } else {
        if (selectedRow == row && selectedCol == col) {
          // Deselect
          selectedRow = null;
          selectedCol = null;
          validMoves = [];
        } else {
          // Attempt move
          final success = widget.engine.makeMove(selectedRow!, selectedCol!, row, col);
          
          if (success) {
            // SMOOTH: Single animation trigger
            _pieceAnimationController.forward().then((_) {
              if (mounted) {
                _pieceAnimationController.reset();
              }
            });

            final move = widget.engine.moveHistory.last;

            // Check if game ended after player move and start visualization
            if (widget.engine.isGameOver) {
              startGameEndVisualization().then((_) {
                widget.onMoveMade?.call(move);
              });
            } else {
              widget.onMoveMade?.call(move);
              
              // REMOVED: No auto AI move checking - let game_screen.dart handle it
            }
          }
          
          // Clear selection
          selectedRow = null;
          selectedCol = null;
          validMoves = [];
        }
      }
    });
  }

  // Helper function to get piece asset path
  String? _getPieceAssetPath(ChessPiece piece) {
    final colorName = piece.color == PieceColor.white ? 'white' : 'black';
    
    switch (piece.type) {
      case PieceType.pawn:
        return 'assets/pieces/${colorName}_pawn.png';
      case PieceType.rook:
        return 'assets/pieces/${colorName}_rook.png';
      case PieceType.knight:
        return 'assets/pieces/${colorName}_knight.png';
      case PieceType.bishop:
        return 'assets/pieces/${colorName}_bishop.png';
      case PieceType.queen:
        return 'assets/pieces/${colorName}_queen.png';
      case PieceType.king:
        return 'assets/pieces/${colorName}_king.png';
    }
  }

  // Fallback Unicode symbols if images don't load
  String _getPieceUnicode(ChessPiece piece) {
    if (piece.color == PieceColor.white) {
      switch (piece.type) {
        case PieceType.king:
          return '♔';
        case PieceType.queen:
          return '♕';
        case PieceType.rook:
          return '♖';
        case PieceType.bishop:
          return '♗';
        case PieceType.knight:
          return '♘';
        case PieceType.pawn:
          return '♙';
      }
    } else {
      switch (piece.type) {
        case PieceType.king:
          return '♚';
        case PieceType.queen:
          return '♛';
        case PieceType.rook:
          return '♜';
        case PieceType.bishop:
          return '♝';
        case PieceType.knight:
          return '♞';
        case PieceType.pawn:
          return '♟';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // STABILITY: Memoize expensive calculations
    final statusColor = _getStatusColor();
    final statusText = _getStatusText();
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.brown[100],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // STABILITY: Fixed size status container to prevent layout shifts
          Container(
            height: 40, // Fixed height prevents jumping
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // STABILITY: Fixed aspect ratio prevents size changes
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: [
                // Main chess board with fixed positioning
                Positioned(
                  left: 20,
                  top: 20,
                  right: 20,
                  bottom: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.brown[800]!, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                      ),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        final row = index ~/ 8;
                        final col = index % 8;
                        
                        final displayRow = widget.isPlayerWhite ? row : 7 - row;
                        final displayCol = widget.isPlayerWhite ? col : 7 - col;
                        
                        return _buildSquare(displayRow, displayCol);
                      },
                    ),
                  ),
                ),
                
                // FIXED: Board coordinates (prevent layout shifts)
                ...List.generate(8, (i) => Positioned(
                  left: 2,
                  top: 20 + (i * (MediaQuery.of(context).size.width - 80) / 8) + ((MediaQuery.of(context).size.width - 80) / 8 - 16) / 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.isPlayerWhite ? 8 - i : i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                  ),
                )),
                
                ...List.generate(8, (i) => Positioned(
                  left: 20 + (i * (MediaQuery.of(context).size.width - 80) / 8) + ((MediaQuery.of(context).size.width - 80) / 8 - 16) / 2,
                  bottom: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: Text(
                      String.fromCharCode(97 + (widget.isPlayerWhite ? i : 7 - i)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // STABILITY: Fixed height status area to prevent layout jumping
          Container(
            height: 50, // Fixed height
            child: Column(
              children: [
                // REMOVED: AI thinking indicator - that's handled by game_screen.dart now
                if (isShowingGameEndVisualization)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.engine.gameState == GameState.checkmate 
                              ? Icons.warning 
                              : Icons.info,
                          color: widget.engine.gameState == GameState.checkmate 
                              ? Colors.red 
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.engine.gameState == GameState.checkmate 
                              ? 'Checkmate - No escape!' 
                              : 'Stalemate - No legal moves!',
                          style: TextStyle(
                            color: widget.engine.gameState == GameState.checkmate 
                                ? Colors.red 
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquare(int row, int col) {
    final piece = widget.engine.board[row][col];
    final isSelected = selectedRow == row && selectedCol == col;
    final isValidMove = validMoves.any((move) => move[0] == row && move[1] == col);
    final isLightSquare = (row + col) % 2 == 0;
    final isLastMoveSquare = widget.engine.lastMove != null &&
        ((widget.engine.lastMove!.fromRow == row && widget.engine.lastMove!.fromCol == col) ||
         (widget.engine.lastMove!.toRow == row && widget.engine.lastMove!.toCol == col));

    // NEW: Check highlighting - get checked king square
    final checkedKing = widget.engine.getCheckedKingSquare();
    final isCheckKingSquare = checkedKing != null &&
        checkedKing[0] == row && checkedKing[1] == col;

    // Check if this square should be highlighted for game end visualization
    final squareKey = '$row,$col';
    final isGameEndHighlighted = isShowingGameEndVisualization && highlightedSquares.contains(squareKey);

    // SMOOTH: Calculate color once to prevent rapid color changes
    Color squareColor;
    if (isSelected) {
      squareColor = Colors.blue[300]!;
    } else if (isCheckKingSquare) {
      // NEW: Subtle red warning overlay only on the checked king's square
      squareColor = Colors.red.withOpacity(0.35);
    } else if (isGameEndHighlighted) {
      final baseColor = widget.engine.gameState == GameState.checkmate 
          ? Colors.red 
          : Colors.orange;
      
      // SMOOTH: More subtle pulsing effect
      final animationValue = _gameEndAnimationController.value;
      final intensity = 0.4 + (animationValue * 0.3); // Gentler pulse range
      squareColor = baseColor.withOpacity(intensity);
    } else if (isLastMoveSquare) {
      squareColor = const Color.fromARGB(140, 174, 175, 177)!;
    } else if (isLightSquare) {
      squareColor = Colors.brown[50]!;
    } else {
      squareColor = Colors.brown[300]!;
    }

    return GestureDetector(
      onTap: () => _onSquareTapped(row, col),
      child: Container( // REMOVED: AnimatedContainer to prevent constant rebuilds
        decoration: BoxDecoration(
          color: squareColor,
          border: isSelected 
              ? Border.all(color: Colors.blue[600]!, width: 3)
              : isGameEndHighlighted
                  ? Border.all(
                      color: widget.engine.gameState == GameState.checkmate 
                          ? Colors.red[800]! 
                          : Colors.orange[800]!, 
                      width: 2
                    )
                  : isCheckKingSquare
                      ? Border.all(color: Colors.red[800]!, width: 2)
                      : null,
        ),
        child: Stack(
          children: [
            if (isValidMove && !isSelected && !isGameEndHighlighted && !isCheckKingSquare)
              Center(
                child: Container(
                  width: piece != null ? 40 : 20,
                  height: piece != null ? 40 : 20,
                  decoration: BoxDecoration(
                    color: piece != null 
                        ? Colors.red.withOpacity(0.7)
                        : Colors.green.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            
            if (piece != null)
              Center(
                child: AnimatedBuilder(
                  animation: _pieceAnimationController,
                  builder: (context, child) {
                    // SMOOTH: Gentler animation scaling
                    final scale = 1.0 + (_pieceAnimationController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        _getPieceAssetPath(piece)!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to Unicode symbols
                          return Text(
                            _getPieceUnicode(piece),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 2,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (isShowingGameEndVisualization) {
      return widget.engine.gameState == GameState.checkmate ? Colors.red : Colors.orange;
    }
    
    switch (widget.engine.gameState) {
      case GameState.check:
        return Colors.orange;
      case GameState.checkmate:
        return Colors.red;
      case GameState.stalemate:
        return Colors.grey;
      case GameState.draw:
        return Colors.blue;
      default:
        return Colors.green; // REMOVED: isThinking reference
    }
  }

  String _getStatusText() {
    if (isShowingGameEndVisualization) {
      return widget.engine.gameState == GameState.checkmate 
          ? 'Checkmate!' 
          : 'Stalemate!';
    }
    
    // REMOVED: isThinking check
    
    switch (widget.engine.gameState) {
      case GameState.check:
        return 'Check!';
      case GameState.checkmate:
        final winner = widget.engine.winner;
        return winner == PieceColor.white ? 'White Wins!' : 'Black Wins!';
      case GameState.stalemate:
        return 'Stalemate - Draw';
      case GameState.draw:
        return 'Draw';
      default:
        final currentPlayer = widget.engine.currentPlayer;
        return currentPlayer == PieceColor.white ? "White's Turn" : "Black's Turn";
    }
  }
}