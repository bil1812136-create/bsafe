import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bsafe_app/features/uwb_positioning/data/models/uwb_model.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

class UwbPositionCanvas extends StatelessWidget {
  final List<UwbAnchor> anchors;
  final UwbTag? currentTag;
  final List<TrajectoryPoint> trajectory;
  final UwbConfig config;
  final double padding;
  final ui.Image? floorPlanImage;

  const UwbPositionCanvas({
    super.key,
    required this.anchors,
    this.currentTag,
    this.trajectory = const [],
    required this.config,
    this.padding = 40.0,
    this.floorPlanImage,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                isComplex: true,
                willChange: true,
                painter: UwbCanvasPainter(
                  anchors: anchors,
                  currentTag: currentTag,
                  trajectory: trajectory,
                  config: config,
                  padding: padding,
                  floorPlanImage: floorPlanImage,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class UwbCanvasPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbTag? currentTag;
  final List<TrajectoryPoint> trajectory;
  final UwbConfig config;
  final double padding;
  final ui.Image? floorPlanImage;

  UwbCanvasPainter({
    required this.anchors,
    this.currentTag,
    required this.trajectory,
    required this.config,
    required this.padding,
    this.floorPlanImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final double minX = anchors.map((a) => a.x).reduce(min) - 1;
    final double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    final double minY = anchors.map((a) => a.y).reduce(min) - 1;
    final double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    final double scaleX = (size.width - padding * 2) / rangeX;
    final double scaleY = (size.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (size.width - rangeX * scale) / 2;
    final double offsetY = (size.height - rangeY * scale) / 2;

    Offset toCanvas(double x, double y) {
      return Offset(
        offsetX + (x - minX) * scale,
        size.height - offsetY - (y - minY) * scale,
      );
    }

    _drawGrid(canvas, size, minX, maxX, minY, maxY, scale, offsetX, offsetY,
        toCanvas);

    if (config.showFloorPlan && floorPlanImage != null) {
      _drawFloorPlan(canvas, size, minX, minY, scale, offsetX, offsetY);
    }

    if (config.showFence && currentTag != null) {
      _drawFence(canvas, toCanvas, scale, currentTag!);
    }

    if (config.showTrajectory && trajectory.isNotEmpty) {
      _drawTrajectory(canvas, toCanvas);
    }

    for (var anchor in anchors) {
      _drawAnchor(canvas, toCanvas(anchor.x, anchor.y), anchor);
    }

    if (currentTag != null) {
      _drawTag(canvas, toCanvas(currentTag!.x, currentTag!.y), currentTag!);
      for (var anchor in anchors) {
        if (currentTag!.anchorDistances.containsKey(anchor.id)) {
          _drawDistanceLine(
            canvas,
            toCanvas(currentTag!.x, currentTag!.y),
            toCanvas(anchor.x, anchor.y),
            currentTag!.anchorDistances[anchor.id]!,
          );
        }
      }
    }

    _drawAxisLabels(canvas, size, minX, maxX, minY, maxY, scale, offsetX,
        offsetY, toCanvas);
  }

  void _drawFloorPlan(Canvas canvas, Size size, double minX, double minY,
      double scale, double offsetX, double offsetY) {
    if (floorPlanImage == null) return;
    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    final double realWidth = imgWidth / config.xScale;
    final double realHeight = imgHeight / config.yScale;
    final double imgRealX = config.xOffset;
    final double imgRealY = config.yOffset;

    final double canvasLeft = offsetX + (imgRealX - minX) * scale;
    final double canvasTop =
        size.height - offsetY - ((imgRealY + realHeight) - minY) * scale;
    final double canvasWidth = realWidth * scale;
    final double canvasHeight = realHeight * scale;

    if (config.flipX) {
      canvas.save();
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }
    if (config.flipY) {
      canvas.save();
      canvas.scale(1, -1);
      canvas.translate(0, -size.height);
    }

    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect =
        Rect.fromLTWH(canvasLeft, canvasTop, canvasWidth, canvasHeight);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, config.floorPlanOpacity);

    canvas.drawImageRect(img, srcRect, dstRect, paint);

    if (config.flipY) canvas.restore();
    if (config.flipX) canvas.restore();
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '等待连接UWB设备...',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawGrid(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;
    final majorGridPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;
    final originPaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2.5;
    final borderPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2.0;

    final double startX = minX.floorToDouble();
    final double startY = minY.floorToDouble();

    for (double x = startX; x <= maxX; x += 0.5) {
      final Paint paint = (x - 0.0).abs() < 0.01
          ? originPaint
          : (x % 1 == 0 ? majorGridPaint : gridPaint);
      canvas.drawLine(toCanvas(x, minY), toCanvas(x, maxY), paint);
    }

    for (double y = startY; y <= maxY; y += 0.5) {
      final Paint paint = (y - 0.0).abs() < 0.01
          ? originPaint
          : (y % 1 == 0 ? majorGridPaint : gridPaint);
      canvas.drawLine(toCanvas(minX, y), toCanvas(maxX, y), paint);
    }

    canvas.drawLine(toCanvas(minX, minY), toCanvas(maxX, minY), borderPaint);
    canvas.drawLine(toCanvas(minX, minY), toCanvas(minX, maxY), borderPaint);
    canvas.drawLine(toCanvas(maxX, maxY), toCanvas(maxX, minY), borderPaint);
    canvas.drawLine(toCanvas(minX, maxY), toCanvas(maxX, maxY), borderPaint);
  }

  void _drawFence(Canvas canvas, Offset Function(double, double) toCanvas,
      double scale, UwbTag tag) {
    final center = toCanvas(tag.x, tag.y);

    final innerPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, config.areaRadius1 * scale, innerPaint);

    final innerBorderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, config.areaRadius1 * scale, innerBorderPaint);

    final outerPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, config.areaRadius2 * scale, outerPaint);

    final outerBorderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 10.0;
    const dashSpace = 5.0;
    final radius = config.areaRadius2 * scale;
    final circumference = 2 * pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashWidth + dashSpace)) / radius;
      final sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        outerBorderPaint,
      );
    }
  }

  void _drawTrajectory(
      Canvas canvas, Offset Function(double, double) toCanvas) {
    if (trajectory.length < 2) return;
    for (int i = 1; i < trajectory.length; i++) {
      final opacity = i / trajectory.length;
      final paint = Paint()
        ..color = Colors.blue.withValues(alpha: opacity * 0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final p1 = toCanvas(trajectory[i - 1].x, trajectory[i - 1].y);
      final p2 = toCanvas(trajectory[i].x, trajectory[i].y);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawAnchor(Canvas canvas, Offset position, UwbAnchor anchor) {
    final basePaint = Paint()
      ..color = Colors.brown.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8, basePaint);

    final towerPaint = Paint()
      ..color = anchor.isActive ? Colors.green.shade700 : Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final iconPath = Path();
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx - 8, position.dy);
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx + 8, position.dy);
    iconPath.moveTo(position.dx - 5, position.dy - 10);
    iconPath.lineTo(position.dx + 5, position.dy - 10);
    canvas.drawPath(iconPath, towerPaint);

    if (anchor.isActive) {
      final wavePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int i = 1; i <= 2; i++) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(position.dx, position.dy - 20),
            width: 15.0 * i,
            height: 10.0 * i,
          ),
          -pi * 0.7,
          pi * 0.4,
          false,
          wavePaint,
        );
      }
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: anchor.id,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(position.dx - textPainter.width / 2, position.dy + 12));
  }

  void _drawTag(Canvas canvas, Offset position, UwbTag tag) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(position + const Offset(2, 2), 12, shadowPaint);

    final tagPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 12, tagPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, 12, borderPaint);

    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(position - const Offset(0, 4), 3, iconPaint);
    canvas.drawLine(position - const Offset(0, 1),
        position + const Offset(0, 5), iconPaint);
    canvas.drawLine(position + const Offset(-4, 1),
        position + const Offset(4, 1), iconPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: tag.id,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(position.dx - textPainter.width / 2, position.dy + 18));
  }

  void _drawDistanceLine(
      Canvas canvas, Offset tagPos, Offset anchorPos, double distance) {
    final double pathLength = (tagPos - anchorPos).distance;
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final int dashCount = (pathLength / (dashWidth + dashSpace)).floor();

    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < dashCount; i++) {
      final double startRatio = (i * (dashWidth + dashSpace)) / pathLength;
      double endRatio = (i * (dashWidth + dashSpace) + dashWidth) / pathLength;
      endRatio = endRatio.clamp(0, 1);
      canvas.drawLine(
        Offset.lerp(tagPos, anchorPos, startRatio)!,
        Offset.lerp(tagPos, anchorPos, endRatio)!,
        linePaint,
      );
    }
  }

  void _drawAxisLabels(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white.withValues(alpha: 0.8),
    );

    final double rangeX = (maxX - minX).abs();
    final double rangeY = (maxY - minY).abs();

    final double intervalX = rangeX > 30 ? 5.0 : (rangeX > 15 ? 2.0 : 1.0);
    final double intervalY = rangeY > 30 ? 5.0 : (rangeY > 15 ? 2.0 : 1.0);

    final double startX = (minX / intervalX).ceilToDouble() * intervalX;
    final double endX = (maxX / intervalX).floorToDouble() * intervalX;
    final double startY = (minY / intervalY).ceilToDouble() * intervalY;
    final double endY = (maxY / intervalY).floorToDouble() * intervalY;

    for (double x = startX; x <= endX; x += intervalX) {
      final pos = toCanvas(x, minY);
      final textPainter = TextPainter(
        text: TextSpan(text: '${x.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(pos.dx - textPainter.width / 2, size.height - offsetY + 8));
    }

    for (double y = startY; y <= endY; y += intervalY) {
      final pos = toCanvas(minX, y);
      final textPainter = TextPainter(
        text: TextSpan(text: '${y.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(offsetX - textPainter.width - 8,
              pos.dy - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant UwbCanvasPainter oldDelegate) {
    if (oldDelegate.currentTag?.x != currentTag?.x ||
        oldDelegate.currentTag?.y != currentTag?.y) {
      return true;
    }
    if (oldDelegate.trajectory.length != trajectory.length) {
      return true;
    }
    if (oldDelegate.anchors != anchors || oldDelegate.config != config) {
      return true;
    }
    if (oldDelegate.floorPlanImage != floorPlanImage) {
      return true;
    }
    return false;
  }
}
