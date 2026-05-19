/// measurement_provider.dart — polygon area (Shoelace) + geometric recognition
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset, Size;
import 'package:vector_math/vector_math.dart' show Vector2;
import 'measurement_mode.dart';

class MeasurementProvider extends ChangeNotifier {
  MeasurementMode _mode          = MeasurementMode.area;
  GeometricShape  _geoShape      = GeometricShape.square;
  final List<Offset> _points     = [];

  MeasurementMode get mode       => _mode;
  GeometricShape  get geoShape   => _geoShape;
  List<Offset>    get points     => List.unmodifiable(_points);

  // ── Mode / shape switching ────────────────────────────────────
  void switchMode(MeasurementMode m) {
    if (_mode == m) return;
    _mode = m;
    _points.clear();
    notifyListeners();
  }

  void switchGeoShape(GeometricShape s) {
    _geoShape = s;
    _points.clear();
    notifyListeners();
  }

  // ── Point capture ─────────────────────────────────────────────
  void capture(Offset normalised) {
    // Geometric mode: only 2 points needed
    if (_mode == MeasurementMode.geometric && _points.length >= 2) {
      _points
        ..clear()
        ..add(normalised);
    } else {
      _points.add(normalised);
    }
    notifyListeners();
  }

  void undo() {
    if (_points.isEmpty) return;
    _points.removeLast();
    notifyListeners();
  }

  void reset() {
    _points.clear();
    notifyListeners();
  }

  // ── Area computation (Shoelace formula) ───────────────────────
  /// Returns real-world area in m² using screen points + laser distance.
  /// [distanceM]    = laser distance in metres
  /// [canvasSize]   = canvas pixel size (to normalise points)
  /// Assumes camera FOV ±30° H, ±22.5° V.
  double polygonAreaM2(Size canvasSize, double distanceM) {
    if (_points.length < 3) return 0;
    final world = _toWorldPoints(_points, canvasSize, distanceM);
    return _shoelace(world);
  }

  // ── Geometric shape computations ──────────────────────────────

  /// Circle: pt0 = centre (normalised), pt1 = rim point.
  double circleRadiusM(Size canvas, double distanceM) {
    if (_points.length < 2) return 0;
    final w = _toWorldPoints(_points, canvas, distanceM);
    return (w[1] - w[0]).length;
  }

  double circleAreaM2(Size canvas, double distanceM) {
    final r = circleRadiusM(canvas, distanceM);
    return math.pi * r * r;
  }

  /// Square: pt0 & pt1 are opposite corners.
  double squareSideM(Size canvas, double distanceM) {
    if (_points.length < 2) return 0;
    final w = _toWorldPoints(_points, canvas, distanceM);
    final diag = (w[1] - w[0]).length;
    return diag / math.sqrt2;
  }

  double squareAreaM2(Size canvas, double distanceM) {
    final s = squareSideM(canvas, distanceM);
    return s * s;
  }

  // ── Private helpers ───────────────────────────────────────────

  List<Vector2> _toWorldPoints(
      List<Offset> pts, Size canvas, double distanceM) {
    const hFov = 30.0 * math.pi / 180;
    const vFov = 22.5 * math.pi / 180;
    return pts.map((p) {
      final nx = (p.dx / canvas.width  - 0.5) * 2;
      final ny = (p.dy / canvas.height - 0.5) * 2;
      return Vector2(
        nx * distanceM * math.tan(hFov),
        ny * distanceM * math.tan(vFov),
      );
    }).toList();
  }

  double _shoelace(List<Vector2> pts) {
    double area = 0;
    final n = pts.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += pts[i].x * pts[j].y;
      area -= pts[j].x * pts[i].y;
    }
    return area.abs() / 2;
  }
}
