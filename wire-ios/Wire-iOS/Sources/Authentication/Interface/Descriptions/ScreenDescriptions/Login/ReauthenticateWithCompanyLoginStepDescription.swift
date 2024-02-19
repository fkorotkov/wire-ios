//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

import Foundation

final class ReauthenticateWithCompanyLoginStepDescription: AuthenticationStepDescription {

    let backButton: BackButtonDescription?
    let mainView: ViewDescriptor & ValueSubmission
    let headline: String
    let subtext: String?
    let secondaryView: AuthenticationSecondaryViewDescription?
    let footerView: AuthenticationFooterViewDescription?

    init() {
        backButton = BackButtonDescription()
        headline = L10n.Localizable.Registration.Signin.title
        subtext = L10n.Localizable.SigninLogout.Sso.subheadline

        mainView = SolidButtonDescription(title: L10n.Localizable.SigninLogout.Sso.buton, accessibilityIdentifier: "company_login")
        secondaryView = nil
        footerView = nil
    }

}
