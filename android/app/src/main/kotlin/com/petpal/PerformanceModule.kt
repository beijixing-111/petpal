package com.petpal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PerformanceModule —— 设备性能状态监控模块
 *
 * 负责监听电池电量、充电状态、设备温度等信息，
 * 为 Flutter 层提供实时的性能模式建议，
 * 帮助 PetPal 应用根据设备状态动态调整 AI 推理强度与动画帧率。
 *
 * 性能模式说明：
 * - NORMAL: 正常模式，全速运行（充电中或电量充足且温度正常）
 * - LOW_POWER: 低功耗模式，降低帧率和推理频率（低电量或高温）
 */
class PerformanceModule(private val context: Context) {

    // ==================== 性能模式枚举 ====================

    enum class PerformanceMode {
        /** 正常模式：全速推理与渲染 */
        NORMAL,
        /** 低功耗模式：降低 AI 推理频率与动画帧率 */
        LOW_POWER
    }

    // ==================== 核心组件 ====================

    private val applicationContext = context.applicationContext
    private val powerManager: PowerManager =
        applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val batteryManager: BatteryManager =
        applicationContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 后台线程池，用于定时轮询 */
    private val pollingExecutor = Executors.newSingleThreadScheduledExecutor()
    private var pollingFuture: ScheduledFuture<*>? = null
    /** 标记是否正在监控 */
    private val isMonitoring = AtomicBoolean(false)

    // ==================== 阈值常量 ====================

    companion object {
        /** 低电量阈值：低于此值时进入低功耗模式 */
        private const val LOW_BATTERY_THRESHOLD = 20

        /** 温度升高阈值（摄氏度），使用 BatteryManager 上报的温度字段 */
        private const val HIGH_TEMP_THRESHOLD_CELSIUS = 40

        /** 默认轮询间隔（毫秒） */
        private const val DEFAULT_POLL_INTERVAL_MS = 5000L
    }

    // ==================== 广播接收器：监听电池变化 ====================

    /**
     * 监听电池状态变化的广播接收器。
     * 在调用 startMonitoring() 时注册，stopMonitoring() 时注销。
     */
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            // 电池状态变化时触发回调
            // 回调通过轮询统一处理，此处仅用于及时性保证
        }
    }

    // ==================== 公开 API ====================

    /**
     * 判断当前设备是否处于低电量状态。
     *
     * 电池电量低于 LOW_BATTERY_THRESHOLD（20%）且未充电时返回 true。
     *
     * @return true 表示处于低电量状态
     */
    fun isLowPower(): Boolean {
        // 检查系统是否开启了省电模式
        if (powerManager.isPowerSaveMode) {
            return true
        }
        // 检查电池电量
        val batteryLevel = getBatteryLevel()
        val isCharging = isCharging()
        return batteryLevel in 1..LOW_BATTERY_THRESHOLD && !isCharging
    }

    /**
     * 获取当前电池电量百分比。
     * 通过 BatteryManager 直接获取，无需广播。
     *
     * @return 电池电量百分比 0-100，获取失败返回 -1
     */
    fun getBatteryLevel(): Int {
        return try {
            val property = BatteryManager.BATTERY_PROPERTY_CAPACITY
            batteryManager.getIntProperty(property)
        } catch (e: Exception) {
            android.util.Log.w("PerformanceModule", "获取电池电量失败: ${e.message}")
            -1
        }
    }

    /**
     * 判断设备当前是否正在充电。
     *
     * @return true 表示正在充电（连接了 USB 或无线充电器）
     */
    fun isCharging(): Boolean {
        return try {
            val batteryStatusIntent = applicationContext.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val status = batteryStatusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
        } catch (e: Exception) {
            android.util.Log.w("PerformanceModule", "获取充电状态失败: ${e.message}")
            false
        }
    }

    /**
     * 获取设备当前温度等级。
     *
     * 兼容 Android 不同版本的 API：
     * - Android 10+ 使用 PowerManager.getCurrentThermalStatus()
     * - 低版本通过 BatteryManager.EXTRA_TEMPERATURE 获取温度并转换为等级
     *
     * @return 温度等级描述字符串
     *   "STATUS_NONE" / "STATUS_LIGHT" / "STATUS_MODERATE" / "STATUS_SEVERE" / "STATUS_CRITICAL" / "STATUS_UNKNOWN"
     */
    fun getThermalStatus(): String {
        // Android 10 (Q) 及以上，使用 PowerManager 的 Thermal API
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                val status = powerManager.currentThermalStatus
                when (status) {
                    PowerManager.THERMAL_STATUS_NONE -> "STATUS_NONE"
                    PowerManager.THERMAL_STATUS_LIGHT -> "STATUS_LIGHT"
                    PowerManager.THERMAL_STATUS_MODERATE -> "STATUS_MODERATE"
                    PowerManager.THERMAL_STATUS_SEVERE -> "STATUS_SEVERE"
                    PowerManager.THERMAL_STATUS_CRITICAL -> "STATUS_CRITICAL"
                    else -> "STATUS_UNKNOWN"
                }
            } catch (e: Exception) {
                android.util.Log.w("PerformanceModule", "获取温度状态失败: ${e.message}")
                "STATUS_UNKNOWN"
            }
        }

        // 低版本通过电池温度手动判断
        val tempCelsius = getBatteryTemperatureCelsius()
        return when {
            tempCelsius < 0 -> "STATUS_UNKNOWN"
            tempCelsius < 35 -> "STATUS_NONE"
            tempCelsius < 40 -> "STATUS_LIGHT"
            tempCelsius < 45 -> "STATUS_MODERATE"
            tempCelsius < 50 -> "STATUS_SEVERE"
            else -> "STATUS_CRITICAL"
        }
    }

    /**
     * 根据当前设备状态，返回建议的性能模式。
     *
     * 判断逻辑：
     * 1. 系统开启了省电模式 → LOW_POWER
     * 2. 低电量 + 未充电 → LOW_POWER
     * 3. 温度过高 → LOW_POWER
     * 4. 其他情况 → NORMAL
     *
     * @return 建议的性能模式
     */
    fun getRecommendedPerformanceMode(): String {
        return when {
            isLowPower() -> PerformanceMode.LOW_POWER.name
            isHighTemperature() -> PerformanceMode.LOW_POWER.name
            else -> PerformanceMode.NORMAL.name
        }
    }

    // ==================== 定时轮询 ====================

    /**
     * 启动性能状态的定时轮询。
     *
     * 每隔指定毫秒收集一次设备状态，并通过回调通知 Flutter 层。
     *
     * @param intervalMs 轮询间隔（毫秒），默认 5000ms
     * @param onUpdate   状态更新回调，参数为包含设备状态信息的 Map
     */
    fun startMonitoring(
        intervalMs: Int = DEFAULT_POLL_INTERVAL_MS.toInt(),
        onUpdate: (Map<String, Any>) -> Unit
    ) {
        if (isMonitoring.compareAndSet(false, true)) {
            // 注册电池状态广播接收器
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_BATTERY_CHANGED)
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
                }
            }
            applicationContext.registerReceiver(batteryReceiver, filter)

            // 启动定时轮询
            pollingFuture = pollingExecutor.scheduleAtFixedRate(
                {
                    val event = collectDeviceStatus()
                    mainHandler.post { onUpdate(event) }
                },
                0, // 立即执行第一次
                intervalMs.coerceAtLeast(1000).toLong(), // 最小间隔 1 秒
                TimeUnit.MILLISECONDS
            )
        }
    }

    /**
     * 停止性能状态轮询。
     *
     * 注销广播接收器并取消定时任务。
     */
    fun stopMonitoring() {
        if (isMonitoring.compareAndSet(true, false)) {
            try {
                applicationContext.unregisterReceiver(batteryReceiver)
            } catch (e: IllegalArgumentException) {
                // 接收器可能未被注册，忽略
            }
            pollingFuture?.cancel(false)
            pollingFuture = null
        }
    }

    /**
     * 释放模块占用的所有资源。
     *
     * 应在 Activity.onDestroy() 中调用。
     */
    fun release() {
        stopMonitoring()
        pollingExecutor.shutdownNow()
    }

    // ==================== 私有辅助方法 ====================

    /**
     * 收集当前设备的完整性能状态信息。
     *
     * @return 包含电池电量、充电状态、温度、性能模式等信息的 Map
     */
    private fun collectDeviceStatus(): Map<String, Any> {
        return mapOf(
            "batteryLevel" to getBatteryLevel(),
            "isCharging" to isCharging(),
            "isPowerSaveMode" to powerManager.isPowerSaveMode,
            "isLowPower" to isLowPower(),
            "thermalStatus" to getThermalStatus(),
            "batteryTemperatureCelsius" to getBatteryTemperatureCelsius(),
            "recommendedPerformanceMode" to getRecommendedPerformanceMode(),
            "timestamp" to System.currentTimeMillis()
        )
    }

    /**
     * 获取电池温度（摄氏度）。
     *
     * 通过 ACTION_BATTERY_CHANGED 广播获取，
     * 原始值为摄氏度的 1/10（需要除以 10）。
     *
     * @return 电池温度（摄氏度），获取失败返回 -1
     */
    private fun getBatteryTemperatureCelsius(): Float {
        return try {
            val batteryIntent = applicationContext.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val temp = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
            if (temp > 0) temp / 10f else -1f
        } catch (e: Exception) {
            android.util.Log.w("PerformanceModule", "获取电池温度失败: ${e.message}")
            -1f
        }
    }

    /**
     * 判断设备是否温度过高。
     *
     * 综合了 Android 10+ 的 Thermal API 和旧版本的电池温度读数。
     *
     * @return true 表示温度过高，建议降低负载
     */
    private fun isHighTemperature(): Boolean {
        // Android 10+ 通过 Thermal API 判断
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                val status = powerManager.currentThermalStatus
                status >= PowerManager.THERMAL_STATUS_MODERATE
            } catch (e: Exception) {
                false
            }
        }
        // 低版本通过电池温度判断
        val temp = getBatteryTemperatureCelsius()
        return temp > HIGH_TEMP_THRESHOLD_CELSIUS
    }
}
