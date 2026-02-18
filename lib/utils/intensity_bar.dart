import 'package:flutter/material.dart';
import 'conversion.dart' as conv;

class IntensityBar extends StatelessWidget {
  final List<double> values; // values in range 0..1
  final double width;
  final double height;
  final String orientation; // 'vertical' or 'horizontal'
  final int? startIndex;
  final int? endIndex;

  const IntensityBar({
    super.key,
    required this.values,
    required this.width,
    required this.height,
    required this.orientation,
    this.startIndex,
    this.endIndex,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _IntensityBarPainter(
        values: values, 
        orientation: orientation,
        startIndex: startIndex,
        endIndex: endIndex,
      ),
    );
  }
}

class _IntensityBarPainter extends CustomPainter {
  final List<double> values;
  final String orientation;
  final int? startIndex;
  final int? endIndex;

  _IntensityBarPainter({
    required this.values, 
    required this.orientation,
    this.startIndex,
    this.endIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    int start = startIndex ?? 0;
    if (start < 0) start = 0;
    int end = endIndex ?? values.length;
    if (end > values.length) end = values.length;
    
    if (orientation == 'horizontal') {
      final rectHeight = size.height;
      final rectWidth = size.width / values.length;
      for (int i = start; i < end; i++) {
        final intensity = values[i].clamp(0.0, 1.0);
        if (intensity < 0.1) continue;
        final color = conv.infernoColormap(intensity);
        final rect = Rect.fromLTWH(
          i * rectWidth, // left
          0, // top
          rectWidth, // width
          rectHeight, // height
        );
        final paint = Paint()..color = color;
        canvas.drawRect(rect, paint);
      }
    } else {
      final rectWidth = size.width;
      final rectHeight = size.height / values.length;
      for (int i = start; i < end; i++) {
        final intensity = values[i].clamp(0.0, 1.0);
        if (intensity < 0.1) continue;
        final color = conv.infernoColormap(intensity);
        final rect = Rect.fromLTWH(
          0, // left
          (values.length - 1 - i) * rectHeight, // top
          rectWidth, // width
          rectHeight, // height
        );
        final paint = Paint()..color = color;
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntensityBarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.orientation != orientation;
}