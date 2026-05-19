/// meter_data.dart
/// ─────────────────────────────────────────────────────────────
/// Immutable snapshot of one BLE measurement packet.
///
/// Wire format from ESP32-S3 (comma-separated UTF-8 string):
///   `"distance_mm,yaw_deg,pitch_deg"`
///   e.g.  `"1250,45.3,-12.7"`
///
/// distance : distance in millimetres (int)
/// yaw      : horizontal angle in degrees (float, -180 … +180)
/// pitch    : vertical angle in degrees   (float, -90 … +90)
/// ─────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;

class MeterData {
  const MeterData({
    required this.distanceMm,
    required this.yawDeg,
    required this.pitchDeg,
    required this.rollDeg,
  });

  final int   distanceMm;
  final double yawDeg;
  final double pitchDeg;
  final double rollDeg;

  // ── Derived measurements ──────────────────────────────────────

  /// Distance in centimetres (1 decimal place)
  double get distanceCm => distanceMm / 10.0;

  /// Distance in metres (3 decimal places)
  double get distanceM  => distanceMm / 1000.0;

  /// Yaw in radians
  double get yawRad   => yawDeg   * math.pi / 180.0;

  /// Pitch in radians
  double get pitchRad => pitchDeg * math.pi / 180.0;

  /// Roll in radians
  double get rollRad => rollDeg * math.pi / 180.0;

  /// Tilt-corrected distance (D_actual = D_measured * cos(pitch))
  double get horizontalM => distanceM * math.cos(pitchRad);

  /// Estimated rectangular area (m²) using horizontal distance as side length
  /// (simplified square-room model: area = d_horizontal²)
  double get estimatedAreaM2 => horizontalM * horizontalM;

  /// Estimated cubic volume (m³) using vertical component as height
  /// (simplified box model: V = area × height)
  double get estimatedVolumeM3 =>
      estimatedAreaM2 * (distanceM * math.sin(pitchRad.abs()));

  // ── Parsing ───────────────────────────────────────────────────

  /// Parse a raw BLE notification byte list.
  ///
  /// Expects UTF-8 string  "distance,pitch,roll".
  /// Returns null if parsing fails so callers can discard bad packets.
  static MeterData? fromBytes(List<int> bytes) {
    try {
      final raw    = String.fromCharCodes(bytes).trim();
      final parts  = raw.split(',');
      if (parts.length < 3) return null;

      final dist  = int.tryParse(parts[0].trim());
      final pitch = double.tryParse(parts[1].trim());
      final roll  = double.tryParse(parts[2].trim());

      if (dist == null || pitch == null || roll == null) return null;

      return MeterData(distanceMm: dist, yawDeg: 0.0, pitchDeg: pitch, rollDeg: roll);
    } catch (_) {
      return null;
    }
  }

  // ── Convenience ───────────────────────────────────────────────

  /// Zero/default state shown before any BLE data arrives
  static const MeterData zero = MeterData(
    distanceMm: 0,
    yawDeg    : 0.0,
    pitchDeg  : 0.0,
    rollDeg   : 0.0,
  );

  @override
  String toString() =>
      'MeterData(dist=$distanceMm mm, yaw=$yawDeg°, pitch=$pitchDeg°, roll=$rollDeg°)';
}
