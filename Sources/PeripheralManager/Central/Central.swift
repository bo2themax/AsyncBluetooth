//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import Foundation
@preconcurrency import CoreBluetooth
import Combine
import os.log

public final class Central: Sendable {
    public let cbCentral: CBCentral

    nonisolated public let isSubscribed = CurrentValueSubject<Bool, Never>(true)

    init(cbCentra: CBCentral) {
        self.cbCentral = cbCentra
    }

    /// The UUID associated with the peer.
    public var identifier: UUID {
        cbCentral.identifier
    }
}
