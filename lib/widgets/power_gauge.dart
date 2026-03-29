import 'package:flutter/material.dart';
import '../design/tokens.dart';

/// Power Gauge widget - shows rep depth/charge progress
/// Vertical bar on left edge that fills as user descends into rep
class PowerGauge extends StatefulWidget {
  final double fillPercent; // 0.0 to 1.0 (can exceed 1.0 for overflow)
  
  const PowerGauge({
    super.key,
    required this.fillPercent,
  });

  @override
  State<PowerGauge> createState() => _PowerGaugeState();
}

class _PowerGaugeState extends State<PowerGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.fillPercent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PowerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fillPercent != widget.fillPercent) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.fillPercent,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get color based on fill percentage
  Color get _gaugeColor {
    // Use the SAME green as the skeleton overlay for visual unity
    const skeletonGreen = Color(0xFF00FF41);

    if (widget.fillPercent >= 1.0) {
      // 100% or more - Full skeleton green (perfect depth)
      return skeletonGreen;
    } else if (widget.fillPercent >= 0.9) {
      // 90-99% - Transition from cyan to skeleton green
      return Color.lerp(AppColors.cyan, skeletonGreen, (widget.fillPercent - 0.9) * 10)!;
    } else {
      // <90% - CYAN (still charging)
      return AppColors.cyan;
    }
  }

  /// Get glow intensity based on fill
  double get _glowIntensity {
    if (widget.fillPercent >= 1.0) {
      return 12.0; // MAX GLOW at 100%+
    } else if (widget.fillPercent >= 0.8) {
      return 6.0 + (widget.fillPercent - 0.8) * 30; // Glow builds 80-100%
    } else {
      return 6.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentFill = _animation.value.clamp(0.0, 1.0);
        
        return Container(
          width: 40,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Filled portion
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 200 * currentFill,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _gaugeColor,
                          _gaugeColor.withOpacity(0.6),
                        ],
                      ),
                      boxShadow: widget.fillPercent >= 1.0
                          ? [
                              BoxShadow(
                                color: _gaugeColor.withOpacity(0.8),
                                blurRadius: _glowIntensity,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                
                // Percentage text (optional, only show at high fill)
                if (currentFill >= 0.5)
                  Positioned(
                    bottom: 10,
                    child: Text(
                      '${(currentFill * 100).toInt()}%',
                      style: TextStyle(
                        color: widget.fillPercent >= 1.0 
                            ? Colors.black 
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

