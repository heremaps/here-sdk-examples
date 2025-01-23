/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

// A simple view to show the next TruckRestrictionWarning event.
class TruckRestrictionView: UIView {
    
    // The dimensions of the rectangle that holds all content.
    // (xy set by the hosting view.)
    var x: CGFloat = 0
    var y: CGFloat = 0
    let w: CGFloat = 125
    let h: CGFloat = 60

    private let margin: CGFloat = 8
    private let cornerRadius: CGFloat = 8.0
    private var customBackgroundColor = UIColor(red: 18/255, green: 109/255, blue: 249/255, alpha: 1)

    var restrictionDescription: String? {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear // Set the background color to transparent
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawRectangleOutlines(_ rect: CGRect) {
        let rectanglePath = UIBezierPath(rect: rect)
        rectanglePath.stroke()
    }

    // Renders text vertically centered in given rectangle.
    // Too long text will be truncated with an ellipsis.
    private func drawTextLeftAligned(_ text: String, rect: CGRect, leftMargin: CGFloat, fontSize: CGFloat) {
        // Set the font and paragraph style for the text.
        let font = UIFont.boldSystemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingTail

        // Set the attributes for the text with a white color.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            // Use white color for text.
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        // Calculate the available width for the text based on the leftMargin.
        let availableWidth = rect.width - leftMargin

        // Calculate the size of the text to be drawn, considering the available width and truncation options.
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size

        // Calculate the y-coordinate to vertically center the text inside the given rectangle.
        let centerY = rect.origin.y + (rect.height - textSize.height) / 2

        // Calculate the x-coordinate for the left-aligned text with the left margin.
        let startX = rect.origin.x + leftMargin

        // Create a rectangle for the text based on the calculated position and size.
        let textRect = CGRect(x: startX, y: centerY, width: textSize.width, height: textSize.height)

        // Draw the text in the calculated rectangle with truncation.
        text.draw(in: textRect, withAttributes: attributes)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let restrictionDescription = restrictionDescription else {
            // Nothing to draw: Clear any previous content.
            return
        }

        // Create a rounded rectangle path for the background of our view.
        let backgroundPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)

        // Set the background color and fill the path.
        customBackgroundColor.setFill()
        backgroundPath.fill()

        drawTextLeftAligned(restrictionDescription, rect: rect, leftMargin: margin, fontSize: 14)
    }
}
