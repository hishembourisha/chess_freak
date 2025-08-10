// File: lib/widgets/chess_board.dart

import 'package:flutter/material.dart';
import '../services/chess_engine.dart';

class ChessBoardWidget extends StatefulWidget {
  final ChessEngine engine;
  final Function(ChessMove)? onMoveMade;
  final bool isPlayerWhite;

  const ChessBoardWidget({
    Key? key,
    required this.engine,
    this.onMoveMade,
    this.isPlayerWhite = true,
  }) : super(key: key);

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with TickerProviderStateMixin {
  int? selectedRow;
  int? selectedCol;
  List<List<int>> validMoves = [];
  bool isThinking = false;
  
  late AnimationController _moveAnimationController;
  late AnimationController _captureAnimationController;
  
  @override
  void initState() {
    super.initState();
    _moveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAIMove();
    });
  }

  @override
  void dispose() {
    _moveAnimationController.dispose();
    _captureAnimationController.dispose();
    super.dispose();
  }

  void _checkForAIMove() {
    if (widget.engine.gameState == GameState.playing &&
        ((widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.black) ||
         (!widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.white))) {
      _makeAIMove();
    }
  }

Future<void> _makeAIMove() async {
  if (isThinking) return;
  
  setState(() {
    isThinking = true;
  });

  // COMPREHENSIVE DEBUG LOGGING
  print('🤖 === AI MOVE DEBUG START ===');
  print('Game state: ${widget.engine.gameState}');
  print('Current player: ${widget.engine.currentPlayer}');
  print('Is game over: ${widget.engine.isGameOver}');
  print('Is in check: ${widget.engine.isCheck}');
  
  // Check if AI has any valid moves at all
  int totalValidMoves = 0;
  List<String> sampleMoves = [];
  
  // Count valid moves by checking all squares
  for (int fromRow = 0; fromRow < 8; fromRow++) {
    for (int fromCol = 0; fromCol < 8; fromCol++) {
      final piece = widget.engine.board[fromRow][fromCol];
      if (piece?.color == widget.engine.currentPlayer) {
        final moves = widget.engine.getValidMoves(fromRow, fromCol);
        totalValidMoves += moves.length;
        
        // Add some sample moves for debugging
        for (var move in moves) {
          if (sampleMoves.length < 5) {
            sampleMoves.add('$fromRow,$fromCol -> ${move[0]},${move[1]}');
          }
        }
      }
    }
  }
  
  print('🎯 Total valid moves found: $totalValidMoves');
  
  if (totalValidMoves == 0) {
    print('❌ NO VALID MOVES FOUND - This should be checkmate or stalemate!');
    print('Current game state should be updated but is: ${widget.engine.gameState}');
  } else {
    print('✅ Valid moves available:');
    for (int i = 0; i < sampleMoves.length; i++) {
      print('   Move ${i+1}: ${sampleMoves[i]}');
    }
  }

  await Future.delayed(Duration(
    milliseconds: widget.engine.difficulty == Difficulty.beginner 
        ? 500 
        : widget.engine.difficulty == Difficulty.intermediate 
            ? 1000 
            : 1500
  ));

  final aiMove = widget.engine.getBestMove();
  print('🎲 getBestMove() returned: $aiMove');
  
  if (aiMove != null) {
    print('🔥 Attempting to make move: ${aiMove.fromRow},${aiMove.fromCol} -> ${aiMove.toRow},${aiMove.toCol}');
    
    // Check if this move is actually valid
    final isValid = widget.engine.isValidMove(aiMove.fromRow, aiMove.fromCol, aiMove.toRow, aiMove.toCol);
    print('🔍 Move validity check: $isValid');
    
    final success = widget.engine.makeMove(
      aiMove.fromRow,
      aiMove.fromCol,
      aiMove.toRow,
      aiMove.toCol,
    );
    print('✅ Move execution result: $success');
    
    if (success) {
      print('🎉 Move successful! New game state: ${widget.engine.gameState}');
      
      _moveAnimationController.forward().then((_) {
        _moveAnimationController.reset();
      });

      if (aiMove.capturedPiece != null) {
        _captureAnimationController.forward().then((_) {
          _captureAnimationController.reset();
        });
      }

      widget.onMoveMade?.call(aiMove);
    } else {
      print('💥 Move failed even though it was returned by getBestMove()!');
    }
  } else {
    print('❌ getBestMove() returned null!');
    print('🔍 Checking if this is actually game over...');
    
    // We can't call _updateGameState() directly since it's private
    // But we can check the current state
    print('🔄 Current game state: ${widget.engine.gameState}');
    print('🔄 Is game over: ${widget.engine.isGameOver}');
    
    if (widget.engine.isGameOver) {
      print('🏁 Game is actually over! Should trigger game over dialog...');
      // The game should end here, but let's see if the UI handles it
    } else {
      print('🤔 Game is not marked as over, but AI has no moves. This is the bug!');
    }
  }

  print('🤖 === AI MOVE DEBUG END ===');

  setState(() {
    isThinking = false;
  });
}

  void _onSquareTapped(int row, int col) {
    if (isThinking || widget.engine.isGameOver) return;

    final isPlayerTurn = (widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.white) ||
                        (!widget.isPlayerWhite && widget.engine.currentPlayer == PieceColor.black);
    
    if (!isPlayerTurn) return;

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
          selectedRow = null;
          selectedCol = null;
          validMoves = [];
        } else {
          final success = widget.engine.makeMove(selectedRow!, selectedCol!, row, col);
          
          if (success) {
            _moveAnimationController.forward().then((_) {
              _moveAnimationController.reset();
            });

            final move = widget.engine.moveHistory.last;
            if (move.capturedPiece != null) {
              _captureAnimationController.forward().then((_) {
                _captureAnimationController.reset();
              });
            }

            widget.onMoveMade?.call(move);
            
            Future.delayed(const Duration(milliseconds: 100), () {
              _checkForAIMove();
            });
          }
          
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: [
                // Main chess board
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
                
                // Row numbers (left side)
                for (int i = 0; i < 8; i++)
                  Positioned(
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
                  ),
                
                // Column letters (bottom)
                for (int i = 0; i < 8; i++)
                  Positioned(
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
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          if (isThinking)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
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

    Color squareColor;
    if (isSelected) {
      squareColor = Colors.blue[300]!;
    } else if (isLastMoveSquare) {
      squareColor = Colors.yellow[300]!;
    } else if (isLightSquare) {
      squareColor = Colors.brown[50]!;  // Light brown squares
    } else {
      squareColor = Colors.brown[300]!;  // Dark brown squares
    }

    return GestureDetector(
      onTap: () => _onSquareTapped(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: squareColor,
          border: isSelected 
              ? Border.all(color: Colors.blue[600]!, width: 3)
              : null,
        ),
        child: Stack(
          children: [
            if (isValidMove && !isSelected)
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
                  animation: _moveAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_moveAnimationController.value * 0.1),
                      child: AnimatedBuilder(
                        animation: _captureAnimationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _captureAnimationController.value * 0.1,
                            child: Image.asset(
                              _getPieceAssetPath(piece)!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Print debug info to help troubleshoot
                                print('Failed to load asset: ${_getPieceAssetPath(piece)}');
                                print('Error: $error');
                                
                                // Fallback to Unicode symbols
                                return Text(
                                  _getPieceUnicode(piece),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: _captureAnimationController.value > 0
                                        ? Colors.red.withOpacity(1 - _captureAnimationController.value)
                                        : Colors.black87,
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
        return isThinking ? Colors.purple : Colors.green;
    }
  }

  String _getStatusText() {
    if (isThinking) return 'AI Thinking...';
    
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