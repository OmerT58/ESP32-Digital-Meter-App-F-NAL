/// measurement_mode.dart — extended with GEOMETRIC and TEST modes
library;

import 'package:flutter/material.dart';

enum MeasurementMode {
  line     ('LINE MODE',        Icons.show_chart_rounded),
  area     ('AREA MODE',        Icons.crop_square_rounded),
  test     ('TEST MODE',        Icons.science_rounded),
  geometric('GEOMETRIC MODE',   Icons.auto_awesome_rounded);

  const MeasurementMode(this.label, this.icon);
  final String   label;
  final IconData icon;
}

/// Sub-shape for GEOMETRIC mode
enum GeometricShape { circle, square }
