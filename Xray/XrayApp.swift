//
//  XrayApp.swift
//  Xray
//
//  Created by pan on 2024/9/14.
//

import SwiftUI
import NetworkExtension

@main
struct XrayApp: App {

    @StateObject private var packetTunnelManager = PacketTunnelManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(packetTunnelManager)
        }
    }
}
