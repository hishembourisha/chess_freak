// lib/widgets/error_counter.dart
import 'package:flutter/material.dart';

class ErrorCounter extends StatefulWidget {
  final int errorCount;
  final int maxErrors;

  const ErrorCounter({
    super.key,
    required this.errorCount,
    this.maxErrors = 3,
  });

  @override
  State<ErrorCounter> createState() => _ErrorCounterState();
}

class _ErrorCounterState extends State<ErrorCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void didUpdateWidget(ErrorCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger shake animation when error count increases
    if (widget.errorCount > oldWidget.errorCount) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.errorCount >= widget.maxErrors
                  ? Colors.red.shade100
                  : widget.errorCount > 0
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.errorCount >= widget.maxErrors
                    ? Colors.red
                    : widget.errorCount > 0
                        ? Colors.orange
                        : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  size: 16,
                  color: widget.errorCount >= widget.maxErrors
                      ? Colors.red
                      : widget.errorCount > 0
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  'Errors: ${widget.errorCount}/${widget.maxErrors}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.errorCount >= widget.maxErrors
                        ? Colors.red.shade800
                        : widget.errorCount > 0
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                // Visual error indicators
                ...List.generate(widget.maxErrors, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      index < widget.errorCount ? Icons.close : Icons.circle_outlined,
                      size: 12,
                      color: index < widget.errorCount
                          ? Colors.red
                          : Colors.grey.shade400,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}