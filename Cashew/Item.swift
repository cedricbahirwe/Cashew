//
//  Item.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
