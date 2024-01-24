/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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

import UIKit

// A simple view to show the current speed limit or current driving speed.
class SpeedView: UIView {   
   
    private let textSize: CGFloat = 18
    var circleColor: UIColor = .red
    
    // The dimensions of the rectangle that holds all content.
    // (xy set by the hosting view.)
    var x: CGFloat = 0
    var y: CGFloat = 0
    let w: CGFloat = 60
    let h: CGFloat = 80
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear // Set the background color to transparent
        speedText = "n/a"
        labelText = ""
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var speedText: String? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var labelText: String? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // Get the context to draw in.
        guard let context = UIGraphicsGetCurrentContext() else { return }
                
        // Calculate the center point of the speed circles.
        let centerX = rect.width / 2
        let centerY = rect.height - w / 2
        let centerPoint = CGPoint(x: centerX, y: centerY)
        
        // Calculate the radius of the outer circle.
        let outerCircleRadius = w / 2
        
        // Set the fill color for the outer circle.
        UIColor.red.setFill()
        
        // Draw the outer circle.
        context.addArc(center: centerPoint, radius: outerCircleRadius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        context.fillPath()
        
        // Calculate the radius of the inner circle.
        let innerCircleRadius = outerCircleRadius * 0.63
        
        // Set the fill color for the inner circle.
        UIColor.white.setFill()
        
        // Draw the inner circle.
        context.addArc(center: centerPoint, radius: innerCircleRadius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        context.fillPath()

        // Render the label text at the top.
        let labelText = labelText ?? ""
        let labelSize = labelText.size(withAttributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: textSize)])
        drawText(labelText, centerX, labelSize.height / 2)
                
        // Render the speed text centered to the inner circle view.
        drawText(speedText ?? "", centerX, centerY)
    }
    
    // Renders text centered on given point.
    private func drawText(_ text: String, _ centerX: Double, _ centerY: Double) {
        // Set the font and paragraph style for the text.
        let font = UIFont.boldSystemFont(ofSize: textSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingTail

        // Set the attributes for the text with a white color.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            // Use black color for text.
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)])
        let textOrigin = CGPoint(x: centerX - textSize.width / 2, y: centerY - textSize.height / 2)

        // Draw the text in the calculated rectangle.
        text.draw(in: CGRect(origin: textOrigin, size: textSize), withAttributes: attributes)
    }
}
