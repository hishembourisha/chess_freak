// lib/widgets/number_pad.dart
import 'package:flutter/material.dart';
import '../services/vibration_service.dart';

class NumberPad extends StatelessWidget {
  final Function(int) onNumberPressed;
  final VoidCallback onHintPressed;
  final VoidCallback onToggleNoteMode;
  final VoidCallback onClearPressed;
  final bool noteMode;
  final int hintBalance;

  const NumberPad({
    super.key,
    required this.onNumberPressed,
    required this.onHintPressed,
    required this.onToggleNoteMode,
    required this.onClearPressed,
    required this.noteMode,
    required this.hintBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Control buttons row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.only(right: 4),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      VibrationService.buttonPressed();
                      onHintPressed();
                    },
                    icon: const Icon(Icons.lightbulb_outline, size: 16),
                    label: Text('Hint ($hintBalance)', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      VibrationService.buttonPressed();
                      onToggleNoteMode();
                    },
                    icon: Icon(
                      noteMode ? Icons.edit : Icons.edit_outlined, 
                      size: 16,
                    ),
                    label: Text(
                      noteMode ? 'Notes' : 'Number', 
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: noteMode ? Colors.green : Colors.grey.shade300,
                      foregroundColor: noteMode ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.only(left: 4),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      VibrationService.buttonPressed();
                      onClearPressed();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Number pad - 3x3 grid (responsive height)
          Expanded(
            child: Column(
              children: [
                // Row 1: 1, 2, 3
                Expanded(
                  child: Row(
                    children: [
                      _buildNumberButton(1),
                      const SizedBox(width: 8),
                      _buildNumberButton(2),
                      const SizedBox(width: 8),
                      _buildNumberButton(3),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Row 2: 4, 5, 6
                Expanded(
                  child: Row(
                    children: [
                      _buildNumberButton(4),
                      const SizedBox(width: 8),
                      _buildNumberButton(5),
                      const SizedBox(width: 8),
                      _buildNumberButton(6),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Row 3: 7, 8, 9
                Expanded(
                  child: Row(
                    children: [
                      _buildNumberButton(7),
                      const SizedBox(width: 8),
                      _buildNumberButton(8),
                      const SizedBox(width: 8),
                      _buildNumberButton(9),
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

  Widget _buildNumberButton(int number) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          VibrationService.buttonPressed();
          onNumberPressed(number);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: noteMode ? Colors.green.shade50 : Colors.blue.shade50,
          foregroundColor: noteMode ? Colors.green.shade800 : Colors.blue.shade800,
          padding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: (noteMode ? Colors.green : Colors.blue).withOpacity(0.3),
        ),
        child: Text(
          number.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}