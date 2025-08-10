// lib/widgets/chess_controls.dart
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';

class ChessControls extends StatelessWidget {
  final VoidCallback onNewGame;
  final VoidCallback onUndoMove;

  const ChessControls({
    super.key,
    required this.onNewGame,
    required this.onUndoMove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                VibrationService.buttonPressed();
                onNewGame();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('New Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                VibrationService.buttonPressed();
                onUndoMove();
              },
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}