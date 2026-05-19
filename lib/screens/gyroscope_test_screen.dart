import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import '../services/ble_service.dart';

class GyroscopeTestScreen extends StatelessWidget {
  const GyroscopeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Pure 3D visualization
          Positioned.fill(
            child: StreamBuilder<List<double>>(
              stream: BleService.instance.dataStream,
              initialData: BleService.instance.latestData,
              builder: (context, snapshot) {
                final data = snapshot.data ?? [0.0, 0.0, 0.0];
                return _PureVisualizer(
                  x: data[0],
                  y: data[1],
                  z: data[2],
                );
              },
            ),
          ),
          // Ghost-like Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0x4DE5E7EB), // Ghost-like 30% opacity white
              ),
              onPressed: () => Navigator.pop(context),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PureVisualizer extends StatelessWidget {
  const _PureVisualizer({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: x, end: x),
      builder: (context, animX, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: y, end: y),
          builder: (context, animY, child) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: z, end: z),
              builder: (context, animZ, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: DeviceRotationPainter(
                    x: animX,
                    y: animY,
                    z: animZ,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class DeviceRotationPainter extends CustomPainter {
  DeviceRotationPainter({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    canvas.translate(cx, cy);

    double xRad = x * math.pi / 180.0;
    double yRad = y * math.pi / 180.0;
    double zRad = z * math.pi / 180.0;

    final vmath.Matrix4 transform = vmath.Matrix4.identity()
      ..setEntry(3, 2, 0.0018) // Perspective
      ..scale(2.0, 2.0, 2.0)
      ..rotateX(xRad)
      ..rotateY(yRad)
      ..rotateZ(zRad);

    // Geometry: Nose(0,0,100), Tail(0,0,-40), WingLeft(-60,10,-30), WingRight(60,10,-30), Keel(0,-20,-10)
    List<vmath.Vector3> pts = [
      vmath.Vector3(0, 0, 100),    // 0: Nose
      vmath.Vector3(0, 0, -40),    // 1: Tail
      vmath.Vector3(-60, 10, -30), // 2: WingLeft
      vmath.Vector3(60, 10, -30),  // 3: WingRight
      vmath.Vector3(0, -20, -10),  // 4: Keel
    ];

    List<Offset> proj = [];
    List<double> depth = [];

    for (final p in pts) {
      vmath.Vector4 v = vmath.Vector4(p.x, p.y, p.z, 1.0);
      v = transform.transform(v);
      
      double w = v.w;
      if (w == 0) w = 0.001;
      
      proj.add(Offset(v.x / w, v.y / w));
      depth.add(v.z / w); 
    }

    final List<List<int>> edges = [
      [0, 1], // Nose -> Tail
      [0, 2], // Nose -> WingLeft
      [0, 3], // Nose -> WingRight
      [0, 4], // Nose -> Keel
      [1, 2], // Tail -> WingLeft
      [1, 3], // Tail -> WingRight
      [1, 4], // Tail -> Keel
      [2, 4], // WingLeft -> Keel
      [3, 4], // WingRight -> Keel
    ];

    // Depth sorting
    final List<List<int>> sortedEdges = List.from(edges)
      ..sort((a, b) {
        double zA = (depth[a[0]] + depth[a[1]]) / 2;
        double zB = (depth[b[0]] + depth[b[1]]) / 2;
        return zB.compareTo(zA);
      });

    final Paint linePaint = Paint()
      ..color = const Color(0xFF6B7280) // matte grey
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint lineGlowPaint = Paint()
      ..color = const Color(0xFF6B7280).withValues(alpha: 0.2)
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..style = PaintingStyle.stroke;

    for (final edge in sortedEdges) {
      int idx1 = edge[0];
      int idx2 = edge[1];
      
      canvas.drawLine(proj[idx1], proj[idx2], lineGlowPaint);
      canvas.drawLine(proj[idx1], proj[idx2], linePaint);
    }
    
    final Paint vertexGlow = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
    final Paint vertexCore = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(proj[i], 6, vertexGlow);
      canvas.drawCircle(proj[i], 2, vertexCore);
    }
  }

  @override
  bool shouldRepaint(covariant DeviceRotationPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y || oldDelegate.z != z;
  }
}
