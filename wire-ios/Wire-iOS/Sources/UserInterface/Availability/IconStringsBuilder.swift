//
// Wire
// Copyright (C) 2024 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit
import WireCommonComponents

public enum IconStringsBuilder {

    static func iconString(
        leadingIcons: [NSTextAttachment],
        title: String,
        trailingIcons: [NSTextAttachment],
        interactive: Bool,
        color: UIColor,
        titleFont: UIFont? = nil
    ) -> NSAttributedString {

        var components: [NSAttributedString] = [
            leadingIcons.map { .init(attachment: $0) },
            [.init(string: title)],
            trailingIcons.map { .init(attachment: $0) }
        ].flatMap(\.self)

        // Adds the down arrow if the view is interactive
        if interactive {
            if let titleFont = titleFont {
                let iconImage: UIImage = StyleKitIcon.downArrow.makeImage(
                    size: .custom(15),
                    color: SemanticColors.Icon.foregroundPlainDownArrow).withRenderingMode(.alwaysTemplate)

                let icon = NSTextAttachment()
                let iconBounds = CGRect(x: 0,
                                        y: (titleFont.capHeight - iconImage.size.height).rounded() / 2,
                                        width: iconImage.size.width,
                                        height: iconImage.size.height)

                icon.bounds = iconBounds
                icon.image = iconImage
                let iconString = NSAttributedString(attachment: icon)
                components.append(iconString)
            } else {
                components.append(NSAttributedString(attachment: .downArrow(color: color, size: .custom(15))))
            }
        }

        // Mirror elements if in a RTL layout
        if !UIApplication.isLeftToRightLayout {
            components.reverse()
        }

        // Add a padding and combine the final attributed string
        let attributedTitle = NSMutableAttributedString(attributedString: components.joined(separator: .init(string: "  ")))

        return attributedTitle && color
    }
}
