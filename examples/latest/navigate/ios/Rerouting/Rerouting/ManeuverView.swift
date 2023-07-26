/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

// A simple view to show the next maneuver event.
class ManeuverView: UIView {
    
    // The default w/h constraint we use to create the icon with IconProvider.
    static var roadShieldDimConstraints: UInt32 = 100
    
    var distanceText: String? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var maneuverText: String? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var maneuverIcon: UIImage? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var roadShieldImage: UIImage? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private let margin: CGFloat = 8
    private let cornerRadius: CGFloat = 8.0
    private var customBackgroundColor = UIColor(red: 18/255, green: 109/255, blue: 249/255, alpha: 1)
    
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
    
    // Renders image centered in given rectangle while preserving it's aspect ratio.
    private func drawImage(_ image: UIImage, rect: CGRect) {
        // Calculate the scaled size of the image to fit inside the given rectangle while preserving its aspect ratio.
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let targetSize = CGSize(width: rect.width, height: rect.height)
        let scaledSize = targetSize.aspectFit(aspectRatio: aspectRatio)

        // Calculate the origin point to center the image inside the given rectangle.
        let originX = rect.origin.x + (rect.width - scaledSize.width) / 2
        let originY = rect.origin.y + (rect.height - scaledSize.height) / 2

        // Draw the image at the calculated origin point and scaled size.
        let imageRect = CGRect(origin: CGPoint(x: originX, y: originY), size: scaledSize)
        image.draw(in: imageRect)
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
    
    private var maneuverIconRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    private var distanceTextRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    private var roadNameTextRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    private var roadShieldIconRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    
    private func setupViewBounds() {
        // The maneuver panel.
        let backgroundX = bounds.origin.x
        let backgroundY = bounds.origin.y
        let backgroundW = bounds.width
        let backgroundH = bounds.height

        // The maneuver icon. Shown left-aligned.
        let maneuverIconX = backgroundX + margin
        let maneuverIconY = backgroundY + margin
        let maneuverIconW = backgroundH - margin * 2
        let maneuverIconH = maneuverIconW
        maneuverIconRect = CGRect(x: maneuverIconX, y: maneuverIconY,
                                  width: maneuverIconW, height: maneuverIconH)
        
        // The distance text. Shown left of maneuver icon, above road name text.
        let distanceTextX = maneuverIconX + maneuverIconW + margin
        let distanceTextY = maneuverIconY
        var distanceTextW = backgroundW - distanceTextX - margin
        let distanceTextH = maneuverIconH / 2
        distanceTextRect = CGRect(x: distanceTextX, y: distanceTextY,
                                  width: distanceTextW, height: distanceTextH)
        
        // The road name text. Shown below distance text.
        let roadNameX = distanceTextX
        let roadNameY = distanceTextY + distanceTextH + margin
        var roadNameW = distanceTextW
        let roadNameH = distanceTextH - margin
        roadNameTextRect = CGRect(x: roadNameX, y: roadNameY,
                                  width: roadNameW, height: roadNameH)
        
        // The road shield icon. Shown right-aligned.
        let roadShieldX = roadNameX + roadNameW - maneuverIconW + margin
        let roadShieldY = distanceTextY
        let roadShieldW = maneuverIconW - margin
        let roadShieldH = maneuverIconH
        roadShieldIconRect = CGRect(x: roadShieldX, y: roadShieldY,
                                  width: roadShieldW, height: roadShieldH)
        
        ManeuverView.roadShieldDimConstraints = UInt32(roadShieldH)
        
        // Reduce available space if no road shield icon is shown.
        if roadShieldImage != nil {
            roadNameW = roadNameW - roadShieldW - margin
            distanceTextW = roadNameW
            
            roadNameTextRect = CGRect(x: roadNameX, y: roadNameY,
                                      width: roadNameW, height: roadNameH)
            distanceTextRect = CGRect(x: distanceTextX, y: distanceTextY,
                                      width: distanceTextW, height: distanceTextH)
        }
        
        // Use this to debug your view's layout.
        // drawRectangleOutlines(maneuverIconRect)
        // drawRectangleOutlines(distanceTextRect)
        // drawRectangleOutlines(roadNameTextRect)
        // drawRectangleOutlines(roadShieldIconRect)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // Create a rounded rectangle path for the background of our view.
        let backgroundPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)

        // Set the background color and fill the path.
        customBackgroundColor.setFill()
        backgroundPath.fill()

        setupViewBounds()
        
        if let image = maneuverIcon {
            drawImage(image, rect: maneuverIconRect)
        }
        
        if let text = distanceText, !text.isEmpty {
            drawTextLeftAligned(text, rect: distanceTextRect, leftMargin: 0, fontSize: 18)
        }
        
        if let secondaryText = maneuverText, !secondaryText.isEmpty {
            drawTextLeftAligned(secondaryText, rect: roadNameTextRect, leftMargin: 0, fontSize: 14)
        }
        
        if let image = roadShieldImage {
            drawImage(image, rect: roadShieldIconRect)
        }
    }
}

extension CGSize {
    /// Calculates the size that maintains the given aspect ratio while fitting within this size.
    ///
    /// - Parameters:
    ///   - aspectRatio: The desired aspect ratio (width / height).
    /// - Returns: A new `CGSize` that maintains the aspect ratio while fitting within the original size.
    func aspectFit(aspectRatio: CGFloat) -> CGSize {
        // Calculate the width and height for the new size based on the given aspect ratio.

        // The target width remains the same as the original width.
        let targetWidth = width
        
        // Calculate the target height based on the target width and the aspect ratio.
        let targetHeight = width / aspectRatio

        // If the target height is greater than the original height, it means the new size would be too tall.
        if targetHeight > height {
            // In this case, we adjust the width so that the height fits within the original size.
            let adjustedWidth = height * aspectRatio
            return CGSize(width: adjustedWidth, height: height)
        } else {
            // If the target height fits within the original size, we use the original width and the calculated height.
            return CGSize(width: targetWidth, height: targetHeight)
        }
    }
}
