import 'package:flutter/material.dart';
import 'conversion.dart' as conv;

// Draws the values as a horizontal or vertical bar, with color intensity based on the value (using inferno colormap).
class IntensityBar extends StatelessWidget {
  final List<double> values; // values in range 0..1
  final double width;
  final double height;
  final String orientation; // 'vertical' or 'horizontal'
  final int? startIndex; // Optional window for values to display (for performance optimization)
  final int? endIndex; // Optional window for values to display (for performance optimization)
  final bool enhancedResolution; // Whether to use enhanced resolution (interpolating between frames)

  const IntensityBar({
    super.key,
    required this.values,
    required this.width,
    required this.height,
    required this.orientation,
    this.startIndex,
    this.endIndex,
    this.enhancedResolution = false,
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
        enhancedResolution: enhancedResolution,
      ),
    );
  }
}

class _IntensityBarPainter extends CustomPainter {
  final List<double> values;
  final String orientation;
  final int? startIndex;
  final int? endIndex;
  final bool enhancedResolution;

  _IntensityBarPainter({
    required this.values, 
    required this.orientation,
    this.startIndex,
    this.endIndex,
    required this.enhancedResolution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    int start = startIndex ?? 0;
    if (start < 0) start = 0;
    int end = endIndex ?? values.length;
    if (end > values.length) end = values.length;

    if (orientation == 'horizontal' && !enhancedResolution) {
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
    } else if (orientation == 'horizontal' && enhancedResolution) {
      final rectHeight = size.height;
      final rectWidth = size.width / values.length;
      for (int i = start; i < end; i++) {
        final intensity = values[i].clamp(0.0, 1.0);
        if (intensity < 0.1) continue;
        final color = conv.infernoColormap(intensity);
        final rect = Rect.fromLTWH(
          (1/4) * rectWidth + i * rectWidth, // left
          0, // top
          (1/2) * rectWidth, // width
          rectHeight, // height
        );
        final paint = Paint()..color = color;
        canvas.drawRect(rect, paint);

        // Interpolate with next frame for enhanced resolution
        if (i == end - 1) break; // Don't draw line after last bar
        final nextIntensity = values[i + 1].clamp(0.0, 1.0);
        final interpolatedIntensity = (intensity + nextIntensity) / 2;
        if (interpolatedIntensity < 0.1) continue;
        final interpolatedColor = conv.infernoColormap(interpolatedIntensity);
        final interpolatedRect = Rect.fromLTWH(
          (3/4) * rectWidth + i * rectWidth, // left
          0, // top
          (1/2) * rectWidth, // width
          rectHeight, // height
        );
        final interpolatedPaint = Paint()..color = interpolatedColor;
        canvas.drawRect(interpolatedRect, interpolatedPaint);
      }
    } else if (orientation == 'vertical' && enhancedResolution) {
      final rectWidth = size.width;
      final rectHeight = size.height / values.length;
      for (int i = start; i < end; i++) {
        final intensity = values[i].clamp(0.0, 1.0);
        if (intensity < 0.1) continue;
        final color = conv.infernoColormap(intensity);
        final rect = Rect.fromLTWH(
          0, // left
          (values.length - 1 - i) * rectHeight + (1/4) * rectHeight, // top
          rectWidth, // width
          (1/2) * rectHeight, // height
        );
        final paint = Paint()..color = color;
        canvas.drawRect(rect, paint);

        // Interpolate with next frame for enhanced resolution
        if (i == end - 1) break; // Don't draw after last bar
        final nextIntensity = values[i + 1].clamp(0.0, 1.0);
        final interpolatedIntensity = (intensity + nextIntensity) / 2;
        if (interpolatedIntensity < 0.1) continue;
        final interpolatedColor = conv.infernoColormap(interpolatedIntensity);
        final interpolatedRect = Rect.fromLTWH(
          0, // left
          (values.length - 1 - i) * rectHeight - (1/4) * rectHeight, // top
          rectWidth, // width
          (1/2) * rectHeight, // height
        );
        final interpolatedPaint = Paint()..color = interpolatedColor;
        canvas.drawRect(interpolatedRect, interpolatedPaint);
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
  bool shouldRepaint(covariant _IntensityBarPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.orientation != orientation ||
        oldDelegate.enhancedResolution != enhancedResolution ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.endIndex != endIndex;
  }
}