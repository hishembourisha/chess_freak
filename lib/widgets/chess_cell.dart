// lib/widgets/chess_cell.dart
import 'package:flutter/material.dart';
import '../services/chess_engine.dart';

class ChessCell extends StatelessWidget {
  final ChessPiece? piece;
  final bool isDark;
  final bool isSelected;
  final bool isValidMove;
  final VoidCallback onTap;

  const ChessCell({
    super.key,
    required this.piece,
    required this.isDark,
    required this.isSelected,
    required this.isValidMove,
    required this.onTap,
  });

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
    Color squareColor = isDark ? Colors.brown.shade700 : Colors.brown.shade200;
    if (isSelected) {
      squareColor = Colors.green.shade400;
    } else if (isValidMove) {
      squareColor = Colors.lightGreen.shade200;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: squareColor,
        child: Center(
          child: piece != null
              ? Image.asset(
                  _getPieceAssetPath(piece!)!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Print debug info to help troubleshoot
                    print('Failed to load asset: ${_getPieceAssetPath(piece!)}');
                    print('Error: $error');
                    
                    // Fallback to Unicode symbols
                    return Text(
                      _getPieceUnicode(piece!),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              : isValidMove
                  ? Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }
}