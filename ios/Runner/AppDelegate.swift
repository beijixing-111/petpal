import UIKit
import Flutter
import AVKit

/// PetPal AppDelegate - 跨平台智能桌面宠物应用 iOS 入口
/// 负责配置所有 MethodChannel 并与原生模块通信
@main
@objc class AppDelegate: FlutterAppDelegate {

    // MARK: - 核心模块引用

    /// 本地 AI 推理桥接器
    private var llamaBridge: LlamaBridge?

    /// 性能与电池状态观察器
    private var performanceObserver: PerformanceObserver?

    /// PiP 画中画控制器
    private var pipController: AVPictureInPictureController?

    /// PiP 专用的 FlutterViewController 引用
    private var pipFlutterVC: FlutterViewController?

    /// 性能回调通道（供 PerformanceObserver 使用）
    private var performanceChannel: FlutterMethodChannel?

    // MARK: - 应用生命周期

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController 不是 FlutterViewController 类型")
        }

        // 配置所有 MethodChannel
        configureMethodChannels(with: controller)

        // 启用电池状态监听
        UIDevice.current.isBatteryMonitoringEnabled = true

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - MethodChannel 配置

    /// 集中配置所有 MethodChannel，绑定原生处理逻辑
    private func configureMethodChannels(with controller: FlutterViewController) {
        let messenger = controller.binaryMessenger

        // ---- com.petpal/llama ----
        let llamaChannel = FlutterMethodChannel(
            name: "com.petpal/llama",
            binaryMessenger: messenger
        )
        llamaBridge = LlamaBridge()
        llamaChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleLlamaCall(call, result: result)
        }

        // ---- com.petpal/performance ----
        let perfChannel = FlutterMethodChannel(
            name: "com.petpal/performance",
            binaryMessenger: messenger
        )
        self.performanceChannel = perfChannel
        performanceObserver = PerformanceObserver(channel: perfChannel)
        perfChannel.setMethodCallHandler { [weak self] call, result in
            self?.handlePerformanceCall(call, result: result)
        }

        // ---- com.petpal/pip ----
        let pipChannel = FlutterMethodChannel(
            name: "com.petpal/pip",
            binaryMessenger: messenger
        )
        pipChannel.setMethodCallHandler { [weak self] call, result in
            self?.handlePipCall(call, result: result)
        }

        // ---- com.petpal/window ----
        let windowChannel = FlutterMethodChannel(
            name: "com.petpal/window",
            binaryMessenger: messenger
        )
        windowChannel.setMethodCallHandler { _, result in
            // iOS 不支持系统级悬浮窗，返回不支持
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "iOS 不支持系统级悬浮窗功能，请使用画中画模式作为替代",
                details: nil
            ))
        }
    }

    // MARK: - llama 通道处理

    /// 处理 com.petpal/llama 通道的调用
    private func handleLlamaCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let bridge = llamaBridge else {
            result(FlutterError(code: "UNAVAILABLE", message: "LlamaBridge 未初始化", details: nil))
            return
        }

        switch call.method {
        case "loadModel":
            // 加载模型
            let args = call.arguments as? [String: Any]
            let modelPath = args?["path"] as? String ?? ""
            bridge.loadModel(path: modelPath) { success, errorMsg in
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "LOAD_FAILED", message: errorMsg, details: nil))
                }
            }

        case "infer":
            // 执行推理
            let args = call.arguments as? [String: Any]
            let prompt = args?["prompt"] as? String ?? ""
            let maxTokens = args?["maxTokens"] as? Int ?? 256
            bridge.infer(prompt: prompt, maxTokens: maxTokens) { text, errorMsg in
                if let text = text {
                    result(text)
                } else {
                    result(FlutterError(code: "INFER_FAILED", message: errorMsg, details: nil))
                }
            }

        case "interrupt":
            // 中断推理
            bridge.interrupt()
            result(nil)

        case "downloadModel":
            // 下载模型文件
            let args = call.arguments as? [String: Any]
            let url = args?["url"] as? String ?? ""
            let destPath = args?["destPath"] as? String ?? ""
            bridge.downloadModel(from: url, to: destPath) { progress in
                // 下载进度回调到 Flutter 层
                // 注意：此处访问 llamaChannel 需要通过存储的引用，简化实现此处略
            } completion: { success, errorMsg in
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "DOWNLOAD_FAILED", message: errorMsg, details: nil))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - performance 通道处理

    /// 处理 com.petpal/performance 通道的调用
    private func handlePerformanceCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let observer = performanceObserver else {
            result(FlutterError(code: "UNAVAILABLE", message: "PerformanceObserver 未初始化", details: nil))
            return
        }

        switch call.method {
        case "getStatus":
            // 获取当前性能状态快照
            let status = observer.getStatus()
            result(status)

        case "isLowPower":
            // 判断是否处于低功耗模式
            result(observer.isLowPower())

        case "getRecommendedMode":
            // 获取建议的性能模式
            result(observer.getRecommendedMode())

        case "startMonitoring":
            // 开启持续监控（向 Flutter 层推送变更）
            observer.startMonitoring()
            result(nil)

        case "stopMonitoring":
            // 停止持续监控
            observer.stopMonitoring()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - PiP 通道处理

    /// 处理 com.petpal/pip 通道的调用
    private func handlePipCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            // 进入画中画模式
            let args = call.arguments as? [String: Any]
            let width = args?["width"] as? Double ?? 300
            let height = args?["height"] as? Double ?? 400
            startPictureInPicture(width: width, height: height) { success, errorMsg in
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "PIP_FAILED", message: errorMsg, details: nil))
                }
            }

        case "stop":
            // 退出画中画模式
            stopPictureInPicture()
            result(nil)

        case "isSupported":
            // 检查设备是否支持画中画
            result(AVPictureInPictureController.isPictureInPictureSupported())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - PiP 实现

    /// 启动画中画模式
    /// 将 Flutter 内容渲染到一个独立的小窗口中
    /// - Parameters:
    ///   - width: PiP 窗口宽度
    ///   - height: PiP 窗口高度
    ///   - completion: 完成回调 (是否成功, 错误信息)
    private func startPictureInPicture(
        width: Double,
        height: Double,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // 检查硬件支持
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            completion(false, "当前设备不支持画中画功能")
            return
        }

        // 如果已有 PiP 实例在运行，先停止
        if pipController?.isPictureInPictureActive == true {
            stopPictureInPicture()
        }

        // 获取当前 active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else {
            completion(false, "无法获取当前 WindowScene")
            return
        }

        // 创建新的 PiP 专用 UIWindow
        let pipWindow = UIWindow(windowScene: windowScene)
        pipWindow.frame = CGRect(x: 0, y: 0, width: width, height: height)
        pipWindow.windowLevel = .normal + 1

        // 创建新的 FlutterViewController 作为 PiP 内容
        let flutterVC = FlutterViewController(
            engine: (window?.rootViewController as? FlutterViewController)?.engine,
            nibName: nil,
            bundle: nil
        )
        self.pipFlutterVC = flutterVC
        pipWindow.rootViewController = flutterVC
        pipWindow.makeKeyAndVisible()

        // ---- 使用 AVPlayerLayer 作为 Source 驱动 PiP ----
        // 注意：AVPictureInPictureController 需要 AVPlayerLayer 作为 source
        // 这里创建一个简单的 AVPlayer 占位，实际渲染由 Flutter 引擎通过
        // FlutterPlatformView 或纹理共享实现
        let player = AVPlayer()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = pipWindow.bounds
        flutterVC.view.layer.addSublayer(playerLayer)

        // 创建 AVPictureInPictureController
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            completion(false, "PiP 控制器初始化失败")
            return
        }

        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        self.pipController = controller

        // 检查是否可以启动 PiP
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            completion(true, nil)
        } else {
            completion(false, "当前状态无法启动画中画")
        }
    }

    /// 停止画中画模式
    private func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
        pipController = nil
        pipFlutterVC = nil
    }
}
