/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

/// A custom widget that mimics TruckRestrictionView from Java.
/// It draws a rounded rectangle with a red stroke and centers a description inside.
class TruckRestrictionView extends StatefulWidget {
  String description = "";
  TruckRestrictionView({Key? key, required this.description}) : super(key: key);

  @override
  State<TruckRestrictionView> createState() => _TruckRestrictionViewState();
}

class _TruckRestrictionViewState extends State<TruckRestrictionView> {
  @override
  Widget build(BuildContext context) {
    // The Java code uses wInDP=160 and hInDP=40.
    return CustomPaint(
      size: const Size(160, 40),
      painter: TruckRestrictionViewPainter(description: widget.description),
    );
  }
}

class TruckRestrictionViewPainter extends CustomPainter {
  String description = "";
  TruckRestrictionViewPainter({required this.description});

  @override
  void paint(Canvas canvas, Size size) {
    if (description.isEmpty) return;

    double textSizeInDP = 15;
    Paint paint = Paint()..isAntiAlias = true;

    // Define the rectangle.
    double left = 0;
    double top = 0;
    double right = 160;
    double bottom = 40;
    double strokeWidth = 6;

    // Adjust rectangle for stroke.
    double innerLeft = left + strokeWidth / 2;
    double innerTop = top + strokeWidth / 2;
    double innerRight = right - strokeWidth / 2;
    double innerBottom = bottom - strokeWidth / 2;
    Rect innerRect = Rect.fromLTWH(innerLeft, innerTop, innerRight - innerLeft, innerBottom - innerTop);

    // Draw white background with rounded corners.
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(10)), paint);

    // Draw red stroke.
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.red;
    paint.strokeWidth = strokeWidth;
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(10)), paint);

    // Draw the description text centered.
    TextSpan span = TextSpan(
      style: TextStyle(color: Colors.black, fontSize: textSizeInDP, fontWeight: FontWeight.bold),
      text: description,
    );
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout();
    Offset textOffset = Offset(innerRect.center.dx - tp.width / 2, innerRect.center.dy - tp.height / 2);
    tp.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant TruckRestrictionViewPainter oldDelegate) {
    return oldDelegate.description != description;
  }
}
