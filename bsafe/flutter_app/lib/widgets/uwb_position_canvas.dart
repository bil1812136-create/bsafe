import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// UWB定位可视化画布
/// 显示基站、标签和轨迹的2D平面图
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

    // 计算坐标范围 - 支援負數座標
    final double minX = anchors.map((a) => a.x).reduce(min) - 1;
    final double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    final double minY = anchors.map((a) => a.y).reduce(min) - 1;
    final double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    // 計算座標範圍寬度
    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    // 计算缩放比例
    final double scaleX = (size.width - padding * 2) / rangeX;
    final double scaleY = (size.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    // 居中偏移
    final double offsetX = (size.width - rangeX * scale) / 2;
    final double offsetY = (size.height - rangeY * scale) / 2;

    // 坐标转换函数 - 支援負數座標
    Offset toCanvas(double x, double y) {
      return Offset(
        offsetX + (x - minX) * scale,
        size.height - offsetY - (y - minY) * scale, // Y轴翻转
      );
    }

    // 绘制背景网格
    _drawGrid(canvas, size, minX, maxX, minY, maxY, scale, offsetX, offsetY,
        toCanvas);

    // 繪製平面地圖背景
    if (config.showFloorPlan && floorPlanImage != null) {
      _drawFloorPlan(canvas, size, minX, minY, scale, offsetX, offsetY);
    }

    // 绘制区域围栏
    if (config.showFence && currentTag != null) {
      _drawFence(canvas, toCanvas, scale, currentTag!);
    }

    // 绘制轨迹
    if (config.showTrajectory && trajectory.isNotEmpty) {
      _drawTrajectory(canvas, toCanvas);
    }

    // 绘制基站
    for (var anchor in anchors) {
      _drawAnchor(canvas, toCanvas(anchor.x, anchor.y), anchor);
    }

    // 绘制标签
    if (currentTag != null) {
      _drawTag(canvas, toCanvas(currentTag!.x, currentTag!.y), currentTag!);

      // 绘制到基站的连线 (距离)
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

    // 绘制坐标轴标签
    _drawAxisLabels(canvas, size, minX, maxX, minY, maxY, scale, offsetX,
        offsetY, toCanvas);
  }

  /// 繪製平面地圖背景圖片
  void _drawFloorPlan(Canvas canvas, Size size, double minX, double minY,
      double scale, double offsetX, double offsetY) {
    if (floorPlanImage == null) return;

    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    // xScale/yScale = 像素/米 (圖片上每米對應多少像素)
    // xOffset/yOffset = 實際座標 (米) - 圖片左上角在 UWB 座標系中的位置
    
    // 計算圖片對應的實際尺寸 (米)
    final double realWidth = imgWidth / config.xScale;
    final double realHeight = imgHeight / config.yScale;

    // 圖片左上角的實際座標 (米)
    final double imgRealX = config.xOffset;
    final double imgRealY = config.yOffset;

    // 轉換到畫布座標
    // 注意：畫布的 Y 軸是反向的 (從上到下遞增)
    final double canvasLeft = offsetX + (imgRealX - minX) * scale;
    final double canvasTop = size.height - offsetY - ((imgRealY + realHeight) - minY) * scale;
    final double canvasWidth = realWidth * scale;
    final double canvasHeight = realHeight * scale;

    // 翻轉處理
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
    final dstRect = Rect.fromLTWH(canvasLeft, canvasTop, canvasWidth, canvasHeight);

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, config.floorPlanOpacity);

    canvas.drawImageRect(img, srcRect, dstRect, paint);

    // 恢復畫布狀態
    if (config.flipY) {
      canvas.restore();
    }
    if (config.flipX) {
      canvas.restore();
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '等待连接UWB设备...',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
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

    // 原點線加粗並使用更明顯的顏色
    final originPaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2.5;
    
    // 外邊框線
    final borderPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2.0;

    // 從整數開始的 minX
    final double startX = (minX).floorToDouble();
    final double startY = (minY).floorToDouble();

    // 垂直线
    for (double x = startX; x <= maxX; x += 0.5) {
      Paint paint;
      if ((x - 0.0).abs() < 0.01) {
        // 使用容差比較避免浮點誤差
        paint = originPaint; // 原點 X=0 線
      } else if (x % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      final p1 = toCanvas(x, minY);
      final p2 = toCanvas(x, maxY);
      canvas.drawLine(p1, p2, paint);
    }

    // 水平线
    for (double y = startY; y <= maxY; y += 0.5) {
      Paint paint;
      if ((y - 0.0).abs() < 0.01) {
        // 使用容差比較避免浮點誤差
        paint = originPaint; // 原點 Y=0 線
      } else if (y % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      final p1 = toCanvas(minX, y);
      final p2 = toCanvas(maxX, y);
      canvas.drawLine(p1, p2, paint);
    }
    
    // 繪製邊框（座標軸）
    final borderTopLeft = toCanvas(minX, maxY);
    final borderTopRight = toCanvas(maxX, maxY);
    final borderBottomLeft = toCanvas(minX, minY);
    final borderBottomRight = toCanvas(maxX, minY);
    
    canvas.drawLine(borderBottomLeft, borderBottomRight, borderPaint); // 底部 X 軸
    canvas.drawLine(borderBottomLeft, borderTopLeft, borderPaint); // 左側 Y 軸
    canvas.drawLine(borderTopRight, borderBottomRight, borderPaint); // 右側
    canvas.drawLine(borderTopLeft, borderTopRight, borderPaint); // 頂部
  }

  void _drawFence(Canvas canvas, Offset Function(double, double) toCanvas,
      double scale, UwbTag tag) {
    final center = toCanvas(tag.x, tag.y);

    // 内围栏
    final innerPaint = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, config.areaRadius1 * scale, innerPaint);

    final innerBorderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, config.areaRadius1 * scale, innerBorderPaint);

    // 外围栏
    final outerPaint = Paint()
      ..color = Colors.orange.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, config.areaRadius2 * scale, outerPaint);

    final outerBorderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // 虚线效果
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

    final path = Path();
    final firstPoint = toCanvas(trajectory.first.x, trajectory.first.y);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < trajectory.length; i++) {
      final point = toCanvas(trajectory[i].x, trajectory[i].y);
      path.lineTo(point.dx, point.dy);
    }

    // 渐变轨迹
    for (int i = 1; i < trajectory.length; i++) {
      final opacity = i / trajectory.length;
      final paint = Paint()
        ..color = Colors.blue.withOpacity(opacity * 0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final p1 = toCanvas(trajectory[i - 1].x, trajectory[i - 1].y);
      final p2 = toCanvas(trajectory[i].x, trajectory[i].y);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawAnchor(Canvas canvas, Offset position, UwbAnchor anchor) {
    // 基站底座
    final basePaint = Paint()
      ..color = Colors.brown.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8, basePaint);

    // 基站图标 (塔形)
    final towerPaint = Paint()
      ..color = anchor.isActive ? Colors.green.shade700 : Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 绘制信号塔
    final iconPath = Path();
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx - 8, position.dy);
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx + 8, position.dy);
    iconPath.moveTo(position.dx - 5, position.dy - 10);
    iconPath.lineTo(position.dx + 5, position.dy - 10);
    canvas.drawPath(iconPath, towerPaint);

    // 信号波
    if (anchor.isActive) {
      final wavePaint = Paint()
        ..color = Colors.green.withOpacity(0.5)
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

    // 基站标签
    final textPainter = TextPainter(
      text: TextSpan(
        text: anchor.id,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy + 12),
    );
  }

  void _drawTag(Canvas canvas, Offset position, UwbTag tag) {
    // 标签阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(position + const Offset(2, 2), 12, shadowPaint);

    // 标签主体
    final tagPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 12, tagPaint);

    // 标签边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, 12, borderPaint);

    // 人形图标
    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 头
    canvas.drawCircle(position - const Offset(0, 4), 3, iconPaint);
    // 身体
    canvas.drawLine(
      position - const Offset(0, 1),
      position + const Offset(0, 5),
      iconPaint,
    );
    // 手臂
    canvas.drawLine(
      position + const Offset(-4, 1),
      position + const Offset(4, 1),
      iconPaint,
    );

    // 标签名称
    final textPainter = TextPainter(
      text: TextSpan(
        text: tag.id,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy + 18),
    );
  }

  void _drawDistanceLine(
      Canvas canvas, Offset tagPos, Offset anchorPos, double distance) {
    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 虚线
    final path = Path();
    path.moveTo(tagPos.dx, tagPos.dy);
    path.lineTo(anchorPos.dx, anchorPos.dy);

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final double pathLength = (tagPos - anchorPos).distance;
    final int dashCount = (pathLength / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final double startRatio = (i * (dashWidth + dashSpace)) / pathLength;
      double endRatio = (i * (dashWidth + dashSpace) + dashWidth) / pathLength;
      endRatio = endRatio.clamp(0, 1);

      final Offset start = Offset.lerp(tagPos, anchorPos, startRatio)!;
      final Offset end = Offset.lerp(tagPos, anchorPos, endRatio)!;
      canvas.drawLine(start, end, linePaint);
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
      backgroundColor: Colors.white.withOpacity(0.8),
    );

    // 計算合適的標籤間隔
    final double rangeX = (maxX - minX).abs();
    final double rangeY = (maxY - minY).abs();
    
    // 根據範圍決定標籤間隔
    double intervalX = 1.0;
    if (rangeX > 30) {
      intervalX = 5.0;
    } else if (rangeX > 15) {
      intervalX = 2.0;
    }
    
    double intervalY = 1.0;
    if (rangeY > 30) {
      intervalY = 5.0;
    } else if (rangeY > 15) {
      intervalY = 2.0;
    }

    // 從整數開始（對齊到間隔）
    final double startX = (minX / intervalX).ceilToDouble() * intervalX;
    final double endX = (maxX / intervalX).floorToDouble() * intervalX;
    final double startY = (minY / intervalY).ceilToDouble() * intervalY;
    final double endY = (maxY / intervalY).floorToDouble() * intervalY;

    // X轴标签 (在底部)
    for (double x = startX; x <= endX; x += intervalX) {
      final pos = toCanvas(x, minY);
      final textPainter = TextPainter(
        text: TextSpan(text: '${x.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          pos.dx - textPainter.width / 2,
          size.height - offsetY + 8,
        ),
      );
    }

    // Y轴标签 (在左側)
    for (double y = startY; y <= endY; y += intervalY) {
      final pos = toCanvas(minX, y);
      final textPainter = TextPainter(
        text: TextSpan(text: '${y.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          offsetX - textPainter.width - 8,
          pos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant UwbCanvasPainter oldDelegate) {
    // 標籤位置變化時需要重繪
    if (oldDelegate.currentTag?.x != currentTag?.x ||
        oldDelegate.currentTag?.y != currentTag?.y) {
      return true;
    }
    // 軌跡變化
    if (oldDelegate.trajectory.length != trajectory.length) {
      return true;
    }
    // 基站或配置變化
    if (oldDelegate.anchors != anchors || oldDelegate.config != config) {
      return true;
    }
    // 平面地圖變化
    if (oldDelegate.floorPlanImage != floorPlanImage) {
      return true;
    }
    return false;
  }
}
