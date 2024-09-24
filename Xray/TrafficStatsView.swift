//
//  TrafficStatsView.swift
//  Xray
//
//  Created by pan on 2024/9/24.
//

import Foundation
import SwiftUI
import LibXray

struct TrafficStatsView: View {
    @EnvironmentObject var packetTunnelManager: PacketTunnelManager // 监听 PacketTunnelManager 的状态
    @State private var downlinkTraffic: String = "0"  // 下行流量
    @State private var uplinkTraffic: String = "0"    // 上行流量
    @State private var sysStats: [String: String] = [:]  // 用于保存系统统计信息的字典
    @State private var base64TrafficString: String = ""  // 用于保存初始化时的 Base64 编码的 trafficString
    
    // 定时器：每秒执行一次
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var trafficPort: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("流量统计:").font(.headline)
            Text("下行流量: \(formatBytes(downlinkTraffic))") // 显示下行流量
            Text("上行流量: \(formatBytes(uplinkTraffic))")    // 显示上行流量
            Text("系统统计:").font(.headline)
            Text("协程数量 (Num Goroutines): \(sysStats["NumGoroutine"] ?? "0")")  // NumGoroutine
            Text("GC 次数 (Num GC): \(sysStats["NumGC"] ?? "无")")  // NumGC
            Text("当前分配内存 (Alloc): \(formatBytes(sysStats["Alloc"] ?? "0"))")  // Alloc
            Text("总分配内存 (Total Alloc): \(formatBytes(sysStats["TotalAlloc"] ?? "0"))")  // TotalAlloc
            Text("系统内存总量 (Sys): \(formatBytes(sysStats["Sys"] ?? "0"))")  // Sys
            Text("内存分配次数 (Mallocs): \(sysStats["Mallocs"] ?? "0")")  // Mallocs
            Text("内存释放次数 (Frees): \(sysStats["Frees"] ?? "0")")  // Frees
            Text("当前存活对象数 (Live Objects): \(sysStats["LiveObjects"] ?? "0")")  // LiveObjects
            Text("GC 暂停总时间 (Pause Total, ns): \(sysStats["PauseTotalNs"] ?? "0")")  // PauseTotalNs
            Text("运行时间 (Uptime, s): \(sysStats["Uptime"] ?? "0")")  // Uptime
        }
        .onAppear {
            initializeTrafficString()  // 视图加载时执行一次
        }
        .onReceive(timer) { _ in
            // 仅在 VPN 连接后获取流量统计
            if packetTunnelManager.status == .connected {
                updateTrafficStats()
            }
        }
    }
    
    // 初始化 trafficString 并进行 Base64 编码，仅执行一次
    private func initializeTrafficString() {
        if let trafficString = "127.0.0.1:\(trafficPort)".data(using: .utf8) {
            base64TrafficString = trafficString.base64EncodedString()
        } else {
            print("字符串编码为 Data 失败")
        }
    }

    // 每秒执行一次的流量统计更新
    private func updateTrafficStats() {
        // 使用已保存的 base64TrafficString
        let res = LibXrayQueryStats(base64TrafficString)  // 获取 Xray 的流量统计

        // 解码 Base64 返回的数据
        if let decodedData = Data(base64Encoded: res) {
            // 尝试将解码后的 Data 转换为字符串（假设是文本或 JSON 字符串）
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                parseXrayResponse(decodedString)
            } else {
                print("无法将数据转换为 UTF-8 字符串")
            }
        } else {
            print("Base64 解码失败")
        }
    }
    
    // 解析返回的 JSON 数据，并更新流量统计和系统统计
    private func parseXrayResponse(_ response: String) {
        // 将 JSON 字符串转换为字典
        if let jsonData = response.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let jsonDict = jsonObject as? [String: Any] {
            
            // 判断 success 是否为 true
            if let success = jsonDict["success"] as? Bool, success {
                
                // 解析 data 中的 sysStats 和 stats
                if let dataDict = jsonDict["data"] as? [String: Any] {
                    
                    // 解析 sysStats
                    if let sysStatsBase64 = dataDict["sysStats"] as? String {
                        if let sysStatsData = Data(base64Encoded: sysStatsBase64) {
                            if let sysStatsString = String(data: sysStatsData, encoding: .utf8),
                               let sysStatsJson = try? JSONSerialization.jsonObject(with: Data(sysStatsString.utf8), options: []) as? [String: Any] {

                                // 更新系统统计信息
                                sysStats = sysStatsJson.mapValues { "\($0)" }
                            } else {
                                print("无法将 sysStatsData 转换为 JSON 对象")
                            }
                        } else {
                            print("无法将 sysStatsBase64 转换为 Data")
                        }
                    }
                    
                    // 解析 stats
                    if let statsBase64 = dataDict["stats"] as? String {
                        // 尝试解码 Base64 为 Data
                        if let statsData = Data(base64Encoded: statsBase64) {
                            
                            // 尝试直接将 statsData 解析为 JSON 对象
                            if let statsJsonObject = try? JSONSerialization.jsonObject(with: statsData, options: []),
                               let statsDict = statsJsonObject as? [String: Any] {

                                // 在这里可以继续解析 statsDict，提取你需要的流量统计数据
                                if let statsArray = statsDict["stat"] as? [[String: Any]] {
                                    for stat in statsArray {
                                        if let name = stat["name"] as? String, let value = stat["value"] as? String {
                                            if name == "inbound>>>socks>>>traffic>>>uplink" {
                                                // 更新上行流量
                                                uplinkTraffic = value  // 将解析到的上行流量赋值到页面
                                            } else if name == "inbound>>>socks>>>traffic>>>downlink" {
                                                // 更新下行流量
                                                downlinkTraffic = value  // 将解析到的下行流量赋值到页面
                                            }
                                        }
                                    }
                                }
                                
                            } else {
                                print("无法将 statsData 解析为 JSON")
                            }

                        } else {
                            print("无法将 Base64 字符串转换为 Data")
                        }
                    }
                    
                } else {
                    print("无法解析 data 中的 sysStats 或 stats")
                }
            } else {
                print("Success is false 或未找到 success 字段")
            }
        } else {
            print("无法将响应解析为 JSON")
        }
    }
    
    // 将字节转换为 MB 或 GB
    private func formatBytes(_ bytesString: String) -> String {
        guard let bytes = Double(bytesString) else { return "0 bytes" }
        
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024
        
        if bytes >= gigabyte {
            return String(format: "%.2f GB", bytes / gigabyte)
        } else if bytes >= megabyte {
            return String(format: "%.2f MB", bytes / megabyte)
        } else if bytes >= kilobyte {
            return String(format: "%.2f KB", bytes / kilobyte)
        } else {
            return "\(Int(bytes)) bytes"
        }
    }
}