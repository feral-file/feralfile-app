//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import Foundation

struct Constant {
    static var appname: String {
        if isInhouse() {
            return "Feral File (Dev)"
        } else {
            return "Feral File"
        }
    }
    
    static let deviceIDKey: String = "device_id_key"

    static let secureMainBundleIdentifiers: Set<String> = [
        "com.bitmark.autonomywallet",
        "com.bitmark.autonomy-wallet.inhouse",
    ]

    static func isInhouse() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown"
        return bundleIdentifier.contains("inhouse")
    }
    

    struct KeychainKey {
        static func personaPrefix(at uuid: UUID) -> String {
            "persona.\(uuid.uuidString)"
        }
    }
}
