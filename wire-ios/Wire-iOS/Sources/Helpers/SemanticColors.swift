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

import SwiftUI
import WireCommonComponents
import WireDataModel

/// Naming convention:
///
/// The names of all SemanticColors should follow the format:
///
///  "<usage>.<context/role>.<state?>"
/// The last part is optional
enum SemanticColors {

    enum Switch {
        static let backgroundOnStateEnabled = UIColor(light: Asset.Colors.green600Light, dark: Asset.Colors.green700Dark)
        static let backgroundOffStateEnabled = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray70)
        static let borderOnStateEnabled = UIColor(light: Asset.Colors.green600Light, dark: Asset.Colors.green500Dark)
        static let borderOffStateEnabled = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
    }

    enum Label {
        static let textDefault = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let textDefaultWhite = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let textWhite = UIColor(light: Asset.Colors.white, dark: Asset.Colors.white)
        static let textMessageDate = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let textSectionFooter = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.gray20)
        static let textSectionHeader = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray50)
        static let textCellSubtitle = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.white)
        static let textNoResults = UIColor(light: Asset.Colors.black, dark: Asset.Colors.gray20)
        static let textSettingsPasswordPlaceholder = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let textLinkHeaderCellTitle = UIColor(light: Asset.Colors.gray100, dark: Asset.Colors.white)
        static let textUserPropertyCellName = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray40)
        static let textConversationQuestOptionInfo = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.gray20)
        static let textConversationListItemSubtitleField = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.gray20)
        static let textMessageDetails = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray40)
        static let textCollectionSecondary = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let textErrorDefault = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let textPasswordRulesCheck = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray20)
        static let textTabBar = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let textFieldFloatingLabel = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray50)
        static let textSecurityEnabled = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)

        static let textReactionCounterSelected = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
        static let textInactive = UIColor(light: Asset.Colors.gray60, dark: Asset.Colors.gray70)
        static let textParticipantDisconnected = UIColor(light: Asset.Colors.red300Light, dark: Asset.Colors.red300Dark)

        // UserCell: e.g. "Paul Nagel (You)"
        static let textYouSuffix = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let textCertificateValid = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let textCertificateInvalid = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let textCertificateVerified = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
    }

    enum SearchBar {
        static let textInputView = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let textInputViewPlaceholder = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let backgroundInputView = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let borderInputView = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray80)
        static let backgroundButton = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
    }

    enum Icon {
        static let backgroundDefault = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let foregroundPlainCheckMark = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let foregroundCheckMarkSelected = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let foregroundPlaceholder = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let borderCheckMark = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray60)
        static let backgroundCheckMark = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray90)
        static let backgroundCheckMarkSelected = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
        static let backgroundSecurityEnabledCheckMark = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let foregroundDefault = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.white)
        static let foregroundDefaultBlack = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let foregroundDefaultWhite = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let foregroundDefaultRed = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let foregroundPlainDownArrow = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.gray20)
        static let backgroundJoinCall = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let foregroundAvailabilityAvailable = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let foregroundAvailabilityBusy = UIColor(light: Asset.Colors.amber500Light, dark: Asset.Colors.amber500Dark)
        static let foregroundAvailabilityAway = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let backgroundPasswordRuleCheck = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray20)
        static let backgroundMissedPhoneCall = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let foregroundMicrophone = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let emojiCategoryDefault = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray60)
        static let emojiCategorySelected = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)

        // The init here is different because in light mode we would like the color of the border
        // to be clear. The initializer in all other cases in this file expects a type of ColorAsset
        // in both light and dark mode.
        static let borderMutedNotifications = UIColor { traits in
            traits.userInterfaceStyle == .dark ? Asset.Colors.gray70.color : .clear
        }

        static let foregroundElapsedTimeSelfDeletingMessage = UIColor(light: Asset.Colors.gray50, dark: Asset.Colors.gray80)
        static let foregroundRemainingTimeSelfDeletingMessage = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray50)

        //  ThreeDotsLoadingView
        static let foregroundLoadingDotInactive = UIColor(light: Asset.Colors.gray50, dark: Asset.Colors.gray80)
        static let foregroundLoadingDotActive = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray50)

        // Audio Icon
        static let foregroundAudio = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)

        // System Message Icon Colors
        static let foregroundExclamationMarkInSystemMessage = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let foregroundCheckMarkInSystemMessage = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)

        static let backgroundLegalHold = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
    }

    enum View {
        static let backgroundDefault = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray100)
        static let backgroundDefaultBlack = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let backgroundDefaultWhite = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let backgroundConversationView = UIColor(light: Asset.Colors.gray10, dark: Asset.Colors.gray95)
        static let backgroundUserCell = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray95)
        static let backgroundUserCellHightLighted = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray100)
        static let backgroundSeparatorCell = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray90)
        static let backgroundSeparatorEditView = UIColor(light: Asset.Colors.gray60, dark: Asset.Colors.gray70)
        static let backgroundConversationList = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray100)
        static let backgroundConversationListTableViewCell = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray95)
        static let borderConversationListTableViewCell = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray90)
        static let backgroundCollectionCell = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray90)
        static let borderCollectionCell = UIColor(light: Asset.Colors.gray30, dark: Asset.Colors.gray80)
        static let backgroundSecurityLevel = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray95)
        static let borderSecurityEnabled = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let backgroundSecurityEnabled = UIColor(light: Asset.Colors.green50Light, dark: Asset.Colors.green900Dark)
        static let backgroundSecurityDisabled = UIColor(light: Asset.Colors.red600Light, dark: Asset.Colors.red500Dark)
        static let backgroundSeparatorConversationView = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let backgroundReplyMessageViewHighlighted = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray80)
        static let borderAvailabilityIcon = UIColor(light: Asset.Colors.gray10, dark: Asset.Colors.gray90)
        static let borderCharacterInputField = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.gray40)
        static let borderCharacterInputFieldEnabled = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
        static let borderInputBar = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray100)
        static let backgroundCallDragBarIndicator = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray70)
        static let backgroundBlue = UIColor(light: Asset.Colors.blue100Light, dark: Asset.Colors.blue900Dark)
        static let backgroundGreen = UIColor(light: Asset.Colors.green100Light, dark: Asset.Colors.green900Dark)
        static let backgroundAmber = UIColor(light: Asset.Colors.amber100Light, dark: Asset.Colors.amber900Dark)
        static let backgroundRed = UIColor(light: Asset.Colors.red100Light, dark: Asset.Colors.red900Dark)
        static let backgroundPurple = UIColor(light: Asset.Colors.purple100Light, dark: Asset.Colors.purple900Dark)
        static let backgroundTurqoise = UIColor(light: Asset.Colors.turquoise100Light, dark: Asset.Colors.turquoise900Dark)
        static let backgroundCallOverlay = UIColor(light: Asset.Colors.black, dark: Asset.Colors.black)
        static let backgroundCallTopOverlay = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)

        // Mention
        static let backgroundBlueUsernameMention = UIColor(light: Asset.Colors.blue50Light, dark: Asset.Colors.blue800Dark)
        static let backgroundGreenUsernameMention = UIColor(light: Asset.Colors.green50Light, dark: Asset.Colors.green800Dark)
        static let backgroundAmberUsernameMention = UIColor(light: Asset.Colors.amber50Light, dark: Asset.Colors.amber800Dark)
        static let backgroundRedUsernameMention = UIColor(light: Asset.Colors.red50Light, dark: Asset.Colors.red800Dark)
        static let backgroundPurpleUsernameMention = UIColor(light: Asset.Colors.purple50Light, dark: Asset.Colors.purple800Dark)
        static let backgroundTurqoiseUsernameMention = UIColor(light: Asset.Colors.turquoise50Light, dark: Asset.Colors.turquoise800Dark)

        // AudioView
        static let backgroundAudioViewOverlay = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray100)
        static let backgroundAudioViewOverlayActive = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray95)

    }

    enum TabBar {
        static let backgroundSeperatorSelected = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let backgroundSeparator = UIColor(light: Asset.Colors.gray50, dark: Asset.Colors.gray80)
    }

    enum PageIndicator {
        static let backgroundDefault = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray90)
    }

    enum Button {
        static let backgroundBarItem = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray90)
        static let backgroundSecondaryEnabled = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray95)
        static let backgroundSecondaryInConversationViewEnabled = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray100)
        static let backgroundSecondaryHighlighted = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray80)
        static let textSecondaryEnabled = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let borderSecondaryEnabled = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray80)
        static let borderSecondaryHighlighted = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray60)
        static let backgroundPrimaryEnabled = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
        static let backgroundPrimaryHighlighted = UIColor(light: Asset.Colors.blue600Light, dark: Asset.Colors.blue400Light)
        static let backgroundPrimaryDisabled = UIColor(light: Asset.Colors.gray50, dark: Asset.Colors.gray70)
        static let textPrimaryEnabled = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let textPrimaryDisabled = UIColor(light: Asset.Colors.gray80, dark: Asset.Colors.black)
        static let textEmptyEnabled = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let textBottomBarNormal = UIColor(light: Asset.Colors.gray90, dark: Asset.Colors.gray50)
        static let textBottomBarSelected = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let textUnderlineEnabled = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Dark)
        static let borderBarItem = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray100)
        static let backgroundLikeEnabled = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
        static let backgroundLikeHighlighted = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let backgroundSendDisabled = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray70)
        static let backgroundInputBarItemEnabled = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray90)
        static let backgroundInputBarItemHighlighted = UIColor(light: Asset.Colors.blue50Light, dark: Asset.Colors.blue800Dark)
        static let borderInputBarItemEnabled = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray100)
        static let borderInputBarItemHighlighted = UIColor(light: Asset.Colors.blue300Light, dark: Asset.Colors.blue700Dark)
        static let textInputBarItemEnabled = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let textInputBarItemHighlighted = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.white)
        static let reactionBorderSelected = UIColor(light: Asset.Colors.blue300Light, dark: Asset.Colors.blue700Dark)
        static let reactionBackgroundSelected = UIColor(light: Asset.Colors.blue50Light, dark: Asset.Colors.blue800Dark)

        /// Calling buttons
        static let backgroundCallingNormal = UIColor(light: Asset.Colors.white, dark: Asset.Colors.gray90)
        static let backgroundCallingSelected = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let backgroundCallingDisabled = UIColor(light: Asset.Colors.gray20, dark: Asset.Colors.gray95)

        static let borderCallingNormal = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray100)
        static let borderCallingSelected = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let borderCallingDisabled = UIColor(light: Asset.Colors.gray40, dark: Asset.Colors.gray95)

        static let iconCallingNormal = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let iconCallingSelected = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let iconCallingDisabled = UIColor(light: Asset.Colors.gray60, dark: Asset.Colors.gray70)

        static let textCallingNormal = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)
        static let textCallingDisabled = UIColor(light: Asset.Colors.gray60, dark: Asset.Colors.gray70)

        static let backgroundPickUp = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let backgroundHangUp = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Dark)
        static let textUnderlineEnabledDefault = UIColor(light: Asset.Colors.black, dark: Asset.Colors.white)

        // Reaction Button
        static let backroundReactionNormal = UIColor(light: Asset.Colors.white, dark: Asset.Colors.black)
        static let borderReactionNormal = UIColor(light: Asset.Colors.gray50, dark: Asset.Colors.gray80)
        static let backgroundReactionSelected = UIColor(light: Asset.Colors.blue50Light, dark: Asset.Colors.blue900Dark)
        static let borderReactionSelected = UIColor(light: Asset.Colors.blue300Light, dark: Asset.Colors.blue700Dark)

        /// Audio Buttons
        static let backgroundAudioMessageOverlay = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)
        static let backgroundconfirmSendingAudioMessage = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Dark)

        // Scroll To Bottom Button
        static let backgroundScrollToBottonEnabled = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray60)
    }

    enum DrawingColors {
        static let black = UIColor(light: Asset.Colors.black, dark: Asset.Colors.black)
        static let white = UIColor(light: Asset.Colors.white, dark: Asset.Colors.white)
        static let blue = UIColor(light: Asset.Colors.blue500Light, dark: Asset.Colors.blue500Light)
        static let green = UIColor(light: Asset.Colors.green500Light, dark: Asset.Colors.green500Light)
        static let yellow = UIColor(light: Asset.Colors.amber500Dark, dark: Asset.Colors.amber500Dark)
        static let red = UIColor(light: Asset.Colors.red500Light, dark: Asset.Colors.red500Light)
        static let orange = UIColor(red: 0.992, green: 0.514, blue: 0.071, alpha: 1)
        static let purple = UIColor(light: Asset.Colors.purple600Light, dark: Asset.Colors.purple600Light)
        static let brown = UIColor(light: Asset.Colors.amber500Light, dark: Asset.Colors.amber500Light)
        static let turquoise = UIColor(light: Asset.Colors.turquoise500Light, dark: Asset.Colors.turquoise500Light)
        static let sky = UIColor(light: Asset.Colors.blue500Dark, dark: Asset.Colors.blue500Dark)
        static let lime = UIColor(light: Asset.Colors.green500Dark, dark: Asset.Colors.green500Dark)
        static let cyan = UIColor(light: Asset.Colors.turquoise500Dark, dark: Asset.Colors.turquoise500Dark)
        static let lilac = UIColor(light: Asset.Colors.purple500Dark, dark: Asset.Colors.purple500Dark)
        static let coral = UIColor(light: Asset.Colors.red500Dark, dark: Asset.Colors.red500Dark)
        static let pink = UIColor(red: 0.922, green: 0.137, blue: 0.608, alpha: 1)
        static let chocolate = UIColor(red: 0.384, green: 0.184, blue: 0, alpha: 1)
        static let gray = UIColor(light: Asset.Colors.gray70, dark: Asset.Colors.gray70)
    }
}

extension UIColor {

    convenience init(light: ColorResource, dark: ColorResource) {
        self.init { traits in
            .init(resource: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    convenience init(light: ColorAsset, dark: ColorAsset) {
        self.init { traits in
            traits.userInterfaceStyle == .dark ? dark.color : light.color
        }
    }
}
