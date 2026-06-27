import Foundation
import UIKit
import Flutter

/// PerformanceObserver - 性能与电池状态观察器
/// 监听电池状态、热状态，并根据系统状况建议性能模式，通过 MethodChannel 回传 Flutter 层
class PerformanceObserver: NSObject {

    // MARK: - 属性

    /// 与 Flutter 通信的 MethodChannel
    private weak var channel: FlutterMethodChannel?

    /// 是否正在持续监控
    private var isMonitoring = false

    /// 上次推送的状态快照（用于避免重复推送相同数据）
    private var lastReportedStatus: [String: Any]?

    // MARK: - 通知名称

    /// 电池状态变化通知
    private let batteryStateChanged = UIDevice.batteryStateDidChangeNotification

    /// 电池电量变化通知
    private let batteryLevelChanged = UIDevice.batteryLevelDidChangeNotification

    /// 热状态变化通知
    private let thermalStateChanged = ProcessInfo.processInfo.thermalStateDidChangeNotification

    // MARK: - 初始化

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    // MARK: - 监控控制

    /// 开启持续监控，监听系统状态变化并实时推送到 Flutter 层
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // 注册电池状态监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: batteryStateChanged,
            object: nil
        )

        // 注册电池电量监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: batteryLevelChanged,
            object: nil
        )

        // 注册热状态监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: thermalStateChanged,
            object: nil
        )

        // 立即推送当前状态
        pushCurrentStatus()

        print("[PerformanceObserver] 已开启持续监控")
    }

    /// 停止持续监控，移除所有监听
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        NotificationCenter.default.removeObserver(self, name: batteryStateChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: batteryLevelChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: thermalStateChanged, object: nil)

        lastReportedStatus = nil

        print("[PerformanceObserver] 已停止持续监控")
    }

    // MARK: - 状态查询

    /// 判断当前是否处于低功耗/低性能场景
    /// 综合电池状态、热状态和系统低电量模式
    /// - Returns: 是否建议降低性能
    func isLowPower() -> Bool {
        // 系统低电量模式
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return true
        }

        // 电池电量极低时也视为低功耗
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel >= 0 && batteryLevel < 0.15 {
            return true
        }

        // 设备过热时降低性能
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .serious || thermalState == .critical {
            return true
        }

        return false
    }

    /// 获取建议的性能模式
    /// - Returns: 性能模式推荐字符串
    ///   - "max": 高性能模式（正常状态）
    ///   - "balanced": 均衡模式（轻度过热或中低电量）
    ///   - "low": 低功耗模式（严重过热或极低电量）
    ///   - "minimal": 最低功耗模式（临界热状态）
    func getRecommendedMode() -> String {
        let thermal = ProcessInfo.processInfo.thermalState
        let battery = UIDevice.current.batteryLevel
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        // 临界热状态 → 最低功耗
        if thermal == .critical {
            return "minimal"
        }

        // 严重过热 或 系统低电量模式 → 低功耗
        if thermal == .serious || isLowPower {
            return "low"
        }

        // 轻度过热 或 电量低于 30% → 均衡
        if thermal == .fair || (battery >= 0 && battery < 0.3) {
            return "balanced"
        }

        // 正常状态 → 高性能
        return "max"
    }

    /// 获取完整的设备状态快照（供 Flutter 层 getStatus 方法使用）
    /// - Returns: 状态字典，包含电池、热状态、性能模式等信息
    func getStatus() -> [String: Any] {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState

        return [
            // 电池相关
            "batteryLevel": batteryLevel >= 0 ? batteryLevel : -1,
            "batteryState": batteryStateString(batteryState),
            "isCharging": (batteryState == .charging || batteryState == .full),

            // 热状态
            "thermalState": thermalStateString(ProcessInfo.processInfo.thermalState),

            // 系统状态
            "isLowPowerModeEnabled": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "isLowPower": isLowPower(),
            "recommendedMode": getRecommendedMode(),

            // 时间戳
            "timestamp": Date().timeIntervalSince1970
        ]
    }

    // MARK: - 通知回调

    /// 电池状态变化（充电/未充电/满电）
    @objc private func batteryStateDidChange(_ notification: Notification) {
        pushCurrentStatus()
    }

    /// 电池电量百分比变化
    @objc private func batteryLevelDidChange(_ notification: Notification) {
        pushCurrentStatus()
    }

    /// 设备热状态变化
    @objc private func thermalStateDidChange(_ notification: Notification) {
        pushCurrentStatus()
    }

    // MARK: - 推送状态到 Flutter

    /// 将当前状态快照推送到 Flutter 层
    private func pushCurrentStatus() {
        guard isMonitoring, let channel = channel else { return }

        let status = getStatus()

        // 去重：如果状态与上次相同则跳过推送
        if let last = lastReportedStatus,
           NSDictionary(dictionary: status).isEqual(to: last) {
            return
        }

        lastReportedStatus = status
        channel.invokeMethod("onPerformanceChanged", arguments: status)
    }

    // MARK: - 辅助方法

    /// 电池状态 → 可读字符串
    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:   return "unknown"
        case .unplugged: return "unplugged"
        case .charging:  return "charging"
        case .full:      return "full"
        @unknown default: return "unknown"
        }
    }

    /// 热状态 → 可读字符串
    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"   // 正常
        case .fair:     return "fair"      // 轻度过热
        case .serious:  return "serious"   // 严重过热
        case .critical: return "critical"   // 临界状态
        @unknown default: return "unknown"
        }
    }

    // MARK: - 析构

    deinit {
        stopMonitoring()
        print("[PerformanceObserver] 已释放")
    }
}
