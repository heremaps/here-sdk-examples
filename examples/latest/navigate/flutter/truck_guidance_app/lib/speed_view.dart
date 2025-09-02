/*
 * Copyright (C) 2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */
import 'package:flutter/material.dart';

/// A custom widget that mimics the SpeedView from Java.
/// It draws a circle with an inner circle and overlays centered text.
class SpeedView extends StatelessWidget {
  final String label;
  final String speed;
  final Color circleColor;

  const SpeedView({Key? key, required this.label, required this.speed, required this.circleColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The Java code uses wInDP=50, yMarginInDP=5, textSizeInDP=15.
    // Here we set the size accordingly.
    return CustomPaint(
      size: const Size(50, 50 + 5 + 15),
      painter: SpeedViewPainter(label: label, speed: speed, circleColor: circleColor),
    );
  }
}

class SpeedViewPainter extends CustomPainter {
  final String label;
  final String speed;
  final Color circleColor;

  SpeedViewPainter({required this.label, required this.speed, required this.circleColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Dimensions (in logical pixels) based on the Java values.
    double wInDP = 50;
    double yMarginInDP = 5;
    double textSizeInDP = 15;
    double radius = wInDP / 2;
    // Circle center is shifted downward by textSizeInDP.
    Offset center = Offset(radius, radius + textSizeInDP);

    Paint paint = Paint()..isAntiAlias = true;

    // Draw outer circle.
    paint.color = circleColor;
    canvas.drawCircle(center, radius, paint);

    // Draw inner circle.
    paint.color = Colors.white;
    double innerCircleRadius = wInDP * 0.37;
    canvas.drawCircle(center, innerCircleRadius, paint);

    // Draw speed text centered in circle.
    if (speed.isNotEmpty) {
      TextSpan speedSpan = TextSpan(
        style: TextStyle(color: Colors.black, fontSize: textSizeInDP, fontWeight: FontWeight.bold),
        text: speed,
      );
      TextPainter speedTP = TextPainter(text: speedSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      speedTP.layout();
      Offset speedOffset = Offset(center.dx - speedTP.width / 2, center.dy - speedTP.height / 2);
      speedTP.paint(canvas, speedOffset);
    }

    // Draw label centered above the circle.
    if (label.isNotEmpty) {
      TextSpan labelSpan = TextSpan(
        style: TextStyle(color: Colors.black, fontSize: textSizeInDP, fontWeight: FontWeight.bold),
        text: label,
      );
      TextPainter labelTP = TextPainter(text: labelSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      labelTP.layout();
      double labelY = center.dy - radius - yMarginInDP * 2 - labelTP.height / 2;
      Offset labelOffset = Offset(center.dx - labelTP.width / 2, labelY);
      labelTP.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant SpeedViewPainter oldDelegate) {
    return oldDelegate.label != label || oldDelegate.speed != speed || oldDelegate.circleColor != circleColor;
  }
}
