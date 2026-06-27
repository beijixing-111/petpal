package com.petpal

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * PetPal 主 Activity
 *
 * 负责初始化 Flutter 引擎并注册所有 MethodChannel，
 * 包括本地 AI 推理、性能监控、悬浮窗管理等通道。
 */
class MainActivity : FlutterActivity() {

    // ==================== MethodChannel 常量 ====================
    companion object {
        /** 悬浮窗权限请求码 */
        private const val REQUEST_OVERLAY_PERMISSION = 1001
    }

    // ==================== 模块实例 ====================
    private lateinit var llamaInference: LlamaInference
    private lateinit var performanceModule: PerformanceModule

    // ==================== MethodChannel 通道 ====================
    private lateinit var llamaChannel: MethodChannel
    private lateinit var performanceChannel: MethodChannel
    private lateinit var pipChannel: MethodChannel
    private lateinit var windowChannel: MethodChannel

    // ==================== Activity 生命周期 ====================

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 初始化本地 AI 推理模块
        llamaInference = LlamaInference(applicationContext)
        // 初始化性能监控模块
        performanceModule = PerformanceModule(applicationContext)
    }

    /**
     * 配置 FlutterEngine，注册所有原生侧 MethodChannel。
     * 此方法在 Flutter 引擎启动时被调用。
     */
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        // ---------- 注册 llama 推理通道 ----------
        llamaChannel = MethodChannel(binaryMessenger, "com.petpal/llama")
        llamaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // 加载 GGUF 模型文件
                "loadModel" -> {
                    val modelPath: String? = call.argument("modelPath")
                    if (modelPath == null) {
                        result.error("INVALID_ARG", "模型路径不能为空", null)
                    } else {
                        try {
                            llamaInference.loadModel(modelPath)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOAD_ERROR", "模型加载失败: ${e.message}", null)
                        }
                    }
                }

                // 执行推理，逐 token 回调
                "infer" -> {
                    val prompt: String? = call.argument("prompt")
                    if (prompt == null) {
                        result.error("INVALID_ARG", "prompt 不能为空", null)
                    } else {
                        try {
                            llamaInference.infer(prompt) { token ->
                                // 将每个生成的 token 通过事件通道回传 Flutter 层
                                runOnUiThread {
                                    llamaChannel.invokeMethod("onToken", mapOf("token" to token))
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INFER_ERROR", "推理失败: ${e.message}", null)
                        }
                    }
                }

                // 中断当前推理
                "interrupt" -> {
                    llamaInference.interrupt()
                    result.success(true)
                }

                // 检查模型是否已加载
                "isModelLoaded" -> {
                    result.success(llamaInference.isModelLoaded())
                }

                // 下载模型文件
                "downloadModel" -> {
                    val url: String? = call.argument("url")
                    val fileName: String? = call.argument("fileName")
                    if (url == null || fileName == null) {
                        result.error("INVALID_ARG", "url 和 fileName 不能为空", null)
                    } else {
                        llamaInference.downloadModel(url, fileName,
                            onProgress = { progress ->
                                runOnUiThread {
                                    llamaChannel.invokeMethod("onDownloadProgress", mapOf("progress" to progress))
                                }
                            },
                            onComplete = { localPath ->
                                runOnUiThread {
                                    result.success(mapOf("localPath" to localPath))
                                }
                            },
                            onError = { errorMsg ->
                                runOnUiThread {
                                    result.error("DOWNLOAD_ERROR", errorMsg, null)
                                }
                            }
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ---------- 注册性能监控通道 ----------
        performanceChannel = MethodChannel(binaryMessenger, "com.petpal/performance")
        performanceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // 查询是否处于低电量模式
                "isLowPower" -> {
                    result.success(performanceModule.isLowPower())
                }

                // 获取当前电池电量
                "getBatteryLevel" -> {
                    result.success(performanceModule.getBatteryLevel())
                }

                // 获取当前设备温度等级
                "getThermalStatus" -> {
                    result.success(performanceModule.getThermalStatus())
                }

                // 获取建议的性能模式
                "getRecommendedPerformanceMode" -> {
                    result.success(performanceModule.getRecommendedPerformanceMode())
                }

                // 启动性能状态轮询
                "startMonitoring" -> {
                    val intervalMs: Int = call.argument("intervalMs") ?: 5000
                    performanceModule.startMonitoring(intervalMs) { event ->
                        runOnUiThread {
                            performanceChannel.invokeMethod("onPerformanceUpdate", event)
                        }
                    }
                    result.success(true)
                }

                // 停止性能状态轮询
                "stopMonitoring" -> {
                    performanceModule.stopMonitoring()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // ---------- 注册画中画/悬浮窗通道（TODO: 待实现） ----------
        pipChannel = MethodChannel(binaryMessenger, "com.petpal/pip")
        pipChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // TODO: 实现悬浮窗宠物展示相关功能
                "showFloatingPet" -> {
                    result.success(false)
                }

                // TODO: 实现隐藏悬浮窗功能
                "hideFloatingPet" -> {
                    result.success(false)
                }

                // TODO: 实现调整悬浮窗位置
                "updatePosition" -> {
                    result.success(false)
                }

                else -> result.notImplemented()
            }
        }

        // ---------- 注册窗口管理通道 ----------
        windowChannel = MethodChannel(binaryMessenger, "com.petpal/window")
        windowChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // 检查悬浮窗权限是否已授予
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }

                // 请求悬浮窗权限
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }

                // 打开应用设置页面（用户手动授权）
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // 释放资源
        performanceModule.stopMonitoring()
        performanceModule.release()
        llamaInference.release()
        super.onDestroy()
    }

    // ==================== 悬浮窗权限管理 ====================

    /**
     * 检查应用是否拥有悬浮窗权限（SYSTEM_ALERT_WINDOW）。
     *
     * Android 6.0 及以上需要用户手动在设置中授予此权限。
     */
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true // 低于 Android 6.0 默认拥有悬浮窗权限
        }
    }

    /**
     * 请求悬浮窗权限。
     *
     * 如果没有权限，将引导用户跳转到系统设置页面手动开启。
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    /**
     * 直接打开应用详情设置页面，方便用户手动管理权限。
     */
    private fun openOverlaySettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }

    /**
     * 处理权限请求返回结果。
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            val granted = hasOverlayPermission()
            // 将权限结果回传给 Flutter 层
            windowChannel.invokeMethod("onOverlayPermissionResult", mapOf("granted" to granted))
        }
    }
}
