// lib/widgets/sudoku_board.dart
import 'package:flutter/material.dart';
import 'sudoku_cell.dart';

class SudokuBoard extends StatelessWidget {
  final List<List<int>> puzzle;
  final List<List<bool>> isFixed;
  final List<List<bool>> isError;
  final List<List<bool>> isHint;
  final List<List<Set<int>>> cornerNotes;
  final int? selectedRow;
  final int? selectedCol;
  final Function(int, int) onCellTap;
  final Animation<double> scaleAnimation;

  const SudokuBoard({
    super.key,
    required this.puzzle,
    required this.isFixed,
    required this.isError,
    required this.isHint,
    required this.cornerNotes,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
    required this.scaleAnimation,
  });

  bool _isHighlighted(int row, int col) {
    return selectedRow == row || selectedCol == col ||
        (selectedRow != null && selectedCol != null &&
         (row ~/ 3) == (selectedRow! ~/ 3) && (col ~/ 3) == (selectedCol! ~/ 3));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final gridSize = (screenWidth - 32).clamp(260.0, 350.0);
          
          return Center(
            child: Container(
              width: gridSize,
              height: gridSize,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: GridView.count(
                crossAxisCount: 9,
                children: List.generate(81, (index) {
                  final row = index ~/ 9;
                  final col = index % 9;
                  
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: (col + 1) % 3 == 0 ? Colors.black : Colors.grey.shade400,
                          width: (col + 1) % 3 == 0 ? 2 : 1,
                        ),
                        bottom: BorderSide(
                          color: (row + 1) % 3 == 0 ? Colors.black : Colors.grey.shade400,
                          width: (row + 1) % 3 == 0 ? 2 : 1,
                        ),
                      ),
                    ),
                    child: SudokuCell(
                      row: row,
                      col: col,
                      value: puzzle[row][col],
                      isFixed: isFixed[row][col],
                      isError: isError[row][col],
                      isHint: isHint[row][col],
                      isSelected: selectedRow == row && selectedCol == col,
                      isHighlighted: _isHighlighted(row, col),
                      notes: cornerNotes[row][col],
                      onTap: () => onCellTap(row, col),
                      scaleAnimation: scaleAnimation,
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}