//
// Wire
// Copyright (C) 2023 Wire Swiss GmbH
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

import SwiftUI
import WireCommonComponents

struct CopyValueView: View {
    var title: String
    var value: String
    var isCopyEnabled: Bool
    var performCopy: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(FontSpec.smallSemiboldFont.swiftUIFont)
                .foregroundColor(SemanticColors.Label.textSectionHeader.swiftUIColor)
                .padding(.bottom, ViewConstants.Padding.small)
            HStack {
                Text(value)
                    .font(FontSpec.normalRegularFont.swiftUIFont.monospaced())
                if isCopyEnabled {
                    Spacer()
                    VStack {
                        SwiftUI.Button(
                            action: copy,
                            label: {
                                Image(.copy)
                                    .renderingMode(.template)
                                    .foregroundColor(SemanticColors.Icon.foregroundDefaultBlack.swiftUIColor)
                        })
                        Spacer()
                    }
                }
            }
        }
    }

    func copy() {
        performCopy?(value)
    }
}
