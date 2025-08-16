import 'package:flutter/material.dart';
import '../services/chess_engine.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final ChessEngine engine;
  final bool showWhiteCaptured;

  const CapturedPiecesWidget({
    super.key,
    required this.engine,
    required this.showWhiteCaptured,
  });

  @override
  Widget build(BuildContext context) {
    final capturedPieces = showWhiteCaptured
        ? engine.whiteCaptured
        : engine.blackCaptured;
    
    // The debug print statements in the build method are for the console only and don't affect the UI.
    // They can be removed, but are not causing the issue you're asking about.
    
    final materialAdvantage = _calculateMaterialAdvantage();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                showWhiteCaptured ? 'White Captured' : 'Black Captured',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Count: ${capturedPieces.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              if (materialAdvantage != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMaterialAdvantageColor(materialAdvantage),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    materialAdvantage > 0 ? '+$materialAdvantage' : '$materialAdvantage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (capturedPieces.isEmpty)
            Container(
              height: 40,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No pieces captured',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  // REMOVED: This is the debug Text widget you need to delete.
                  // Text(
                  //   'Debug: W:${engine.whiteCaptured.length} B:${engine.blackCaptured.length}',
                  //   style: TextStyle(
                  //     color: Colors.red,
                  //     fontSize: 10,
                  //   ),
                  // ),
                ],
              ),
            )
          else
            _buildCapturedPiecesGrid(capturedPieces),
        ],
      ),
    );
  }

  Widget _buildCapturedPiecesGrid(List<ChessPiece> pieces) {
    final groupedPieces = <PieceType, List<ChessPiece>>{};
    for (final piece in pieces) {
      groupedPieces.putIfAbsent(piece.type, () => []).add(piece);
    }

    final sortedTypes = groupedPieces.keys.toList()
      ..sort((a, b) => _getPieceValue(b).compareTo(_getPieceValue(a)));

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: sortedTypes.expand((type) {
        final piecesOfType = groupedPieces[type]!;
        return piecesOfType.map((piece) => _buildCapturedPiece(piece));
      }).toList(),
    );
  }

  Widget _buildCapturedPiece(ChessPiece piece) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          _getPieceAssetPath(piece)!,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              _getPieceUnicode(piece),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }

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

  int _calculateMaterialAdvantage() {
    int whiteCapturedValue = 0;
    int blackCapturedValue = 0;

    for (final piece in engine.whiteCaptured) {
      whiteCapturedValue += piece.value;
    }
    for (final piece in engine.blackCaptured) {
      blackCapturedValue += piece.value;
    }

    final capturedPieces = showWhiteCaptured ? engine.whiteCaptured : engine.blackCaptured;
    if (capturedPieces.isEmpty) {
      return 0;
    }

    if (showWhiteCaptured) {
      return whiteCapturedValue - blackCapturedValue;
    } else {
      return blackCapturedValue - whiteCapturedValue;
    }
  }

  Color _getMaterialAdvantageColor(int advantage) {
    if (advantage > 0) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  int _getPieceValue(PieceType type) {
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