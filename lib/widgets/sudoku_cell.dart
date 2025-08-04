// lib/widgets/sudoku_cell.dart
import 'package:flutter/material.dart';

class SudokuCell extends StatelessWidget {
  final int row;
  final int col;
  final int value;
  final bool isFixed;
  final bool isError;
  final bool isHint;
  final bool isSelected;
  final bool isHighlighted;
  final Set<int> notes;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;

  const SudokuCell({
    super.key,
    required this.row,
    required this.col,
    required this.value,
    required this.isFixed,
    required this.isError,
    required this.isHint,
    required this.isSelected,
    required this.isHighlighted,
    required this.notes,
    required this.onTap,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white;
    if (isError) {
      backgroundColor = Colors.red.shade100;
    } else if (isHint) {
      backgroundColor = Colors.blue.shade100;
    } else if (isSelected) {
      backgroundColor = Colors.blue.shade200;
    } else if (isHighlighted) {
      backgroundColor = Colors.grey.shade200;
    } else if (isFixed) {
      backgroundColor = Colors.grey.shade100;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? scaleAnimation.value : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: _buildCellContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCellContent() {
    if (value != 0) {
      // Show the main number
      return Center(
        child: Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
            color: isError 
                ? Colors.red 
                : isHint 
                    ? Colors.blue 
                    : isFixed 
                        ? Colors.black87 
                        : Colors.blue.shade800,
          ),
        ),
      );
    } else if (notes.isNotEmpty) {
      // Show corner notes in a 3x3 grid
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: GridView.count(
          crossAxisCount: 3,
          children: List.generate(9, (index) {
            final number = index + 1;
            return Center(
              child: Text(
                notes.contains(number) ? number.toString() : '',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      );
    } else {
      // Empty cell
      return const SizedBox();
    }
  }
}