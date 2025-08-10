import 'package:flutter/material.dart';
import '../services/chess_engine.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final ChessEngine engine;
  final bool showWhiteCaptured;

  const CapturedPiecesWidget({
    Key? key,
    required this.engine,
    required this.showWhiteCaptured,
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  final capturedPieces = showWhiteCaptured 
      ? engine.whiteCaptured 
      : engine.blackCaptured;
  
  // 🐛 DEBUG: Add this section
  print('🔍 === CAPTURED PIECES DEBUG ===');
  print('showWhiteCaptured: $showWhiteCaptured');
  print('engine.whiteCaptured.length: ${engine.whiteCaptured.length}');
  print('engine.blackCaptured.length: ${engine.blackCaptured.length}');
  print('capturedPieces.length: ${capturedPieces.length}');
  
  print('White captured pieces:');
  for (int i = 0; i < engine.whiteCaptured.length; i++) {
    final piece = engine.whiteCaptured[i];
    print('  $i: ${piece.color} ${piece.type}');
  }
  
  print('Black captured pieces:');
  for (int i = 0; i < engine.blackCaptured.length; i++) {
    final piece = engine.blackCaptured[i];
    print('  $i: ${piece.color} ${piece.type}');
  }
  print('🔍 === DEBUG END ===');
  // 🐛 DEBUG: End of debug section
  
  final materialAdvantage = _calculateMaterialAdvantage();
  
  return Container(
    // ... keep all your existing container code exactly the same
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
            
            // 🐛 DEBUG: Add this debug counter
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
            // 🐛 DEBUG: End debug counter
            
            if (materialAdvantage != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getMaterialAdvantageColor(materialAdvantage),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  materialAdvantage > 0 ? '+${materialAdvantage}' : '$materialAdvantage',
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
                // 🐛 DEBUG: Add this debug line
                Text(
                  'Debug: W:${engine.whiteCaptured.length} B:${engine.blackCaptured.length}',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                  ),
                ),
                // 🐛 DEBUG: End debug line
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
            // Fallback to Unicode symbols if PNG loading fails
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

  // Helper function to get piece asset path (same as chess board)
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

  int _calculateMaterialAdvantage() {
    int whiteCapturedValue = 0;
    int blackCapturedValue = 0;

    // Calculate total value of captured pieces
    for (final piece in engine.whiteCaptured) {
      whiteCapturedValue += piece.value;
    }
    for (final piece in engine.blackCaptured) {
      blackCapturedValue += piece.value;
    }

    // Only show advantage if this section actually has pieces AND there's a difference
    final capturedPieces = showWhiteCaptured ? engine.whiteCaptured : engine.blackCaptured;
    if (capturedPieces.isEmpty) {
      return 0; // Don't show any advantage if no pieces captured
    }

    if (showWhiteCaptured) {
      // Showing white captured pieces - show how much MORE white was captured
      return whiteCapturedValue - blackCapturedValue;
    } else {
      // Showing black captured pieces - show how much MORE black was captured  
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