//
//  Item.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
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
