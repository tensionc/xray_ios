//
//  InfoRow.swift
//  Xray
//
//  Created by pan on 2024/9/20.
//

import Foundation
import SwiftUI

struct InfoRow: View {
    var label: String
    var text: String

    var body: some View {
        HStack {
            Text(label)
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
