package com.petpal

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * LlamaInference —— 本地 AI 推理模块
 *
 * 通过 JNI 调用 llama.cpp 原生库，实现 GGUF 量化模型的加载与推理。
 * 支持流式 token 输出、模型下载管理及线程安全的中断机制。
 *
 * 前置条件：libllama.so 已通过 System.loadLibrary 加载。
 */
class LlamaInference(private val context: Context) {

    // ==================== JNI 原生方法声明 ====================

    /**
     * 加载 GGUF 模型到内存。
     * @param modelPath 模型文件的绝对路径
     * @return 加载是否成功
     */
    private external fun nativeLoadModel(modelPath: String): Boolean

    /**
     * 执行单步推理，生成下一个 token。
     * @param prompt 输入提示词
     * @return 生成的文本片段，空字符串表示推理结束
     */
    private external fun nativeInfer(prompt: String): String

    /**
     * 中断当前推理过程。
     */
    private external fun nativeInterrupt()

    /**
     * 释放原生侧模型资源。
     */
    private external fun nativeReleaseModel()

    // ==================== 状态管理 ====================
    private val lock = ReentrantLock()
    /** 标记模型是否已成功加载 */
    private val modelLoaded = AtomicBoolean(false)
    /** 标记是否正在推理中 */
    private val isInferring = AtomicBoolean(false)
    /** 标记是否收到中断请求 */
    private val interrupted = AtomicBoolean(false)

    /** 用于模型下载的后台线程池 */
    private val downloadExecutor = Executors.newSingleThreadExecutor()

    // ==================== 模型路径常量 ====================

    companion object {
        /** 模型文件存储目录名 */
        private const val MODELS_DIR = "models"
    }

    /** 获取模型存放的私有目录 */
    private val modelsDir: File
        get() {
            val dir = File(context.filesDir, MODELS_DIR)
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    // ---------- 初始化：加载原生库 ----------
    init {
        try {
            System.loadLibrary("llama")
        } catch (e: UnsatisfiedLinkError) {
            // 如果加载失败，记录错误但不阻塞 App 启动
            android.util.Log.e("LlamaInference", "无法加载 libllama.so: ${e.message}")
        }
    }

    // ==================== 公开 API ====================

    /**
     * 加载指定的 GGUF 模型文件。
     *
     * 该方法会调用 JNI 将模型加载进内存，加载成功后 isModelLoaded() 返回 true。
     *
     * @param modelPath 模型文件的绝对路径
     * @throws IllegalStateException 如果模型已在加载状态
     * @throws IllegalArgumentException 如果模型文件不存在
     */
    fun loadModel(modelPath: String) {
        lock.withLock {
            if (modelLoaded.get()) {
                throw IllegalStateException("模型已加载，请先释放当前模型")
            }
            val file = File(modelPath)
            if (!file.exists()) {
                throw IllegalArgumentException("模型文件不存在: $modelPath")
            }
            val success = nativeLoadModel(file.absolutePath)
            if (success) {
                modelLoaded.set(true)
            } else {
                throw RuntimeException("原生层加载模型失败")
            }
        }
    }

    /**
     * 执行流式推理，每生成一个 token 触发一次回调。
     *
     * 该方法运行在调用线程（建议在后台线程调用，避免阻塞 UI）。
     * 可通过 interrupt() 在任意线程安全中断。
     *
     * @param prompt   用户输入提示词
     * @param callback 每个 token 的回调函数，参数为生成的文本片段
     */
    fun infer(prompt: String, callback: (String) -> Unit) {
        if (!modelLoaded.get()) {
            throw IllegalStateException("模型未加载，请先调用 loadModel()")
        }

        // 防止并发推理
        if (!isInferring.compareAndSet(false, true)) {
            throw IllegalStateException("推理正在进行中，请等待完成或调用 interrupt()")
        }

        interrupted.set(false)

        try {
            var accumulatedPrompt = prompt
            while (!interrupted.get()) {
                val token = nativeInfer(accumulatedPrompt)
                if (token.isEmpty() || interrupted.get()) {
                    break // 推理结束或被中断
                }
                callback(token)
                // 将已生成的 token 追加到 prompt 中以持续生成
                accumulatedPrompt += token
            }
        } finally {
            isInferring.set(false)
            interrupted.set(false)
        }
    }

    /**
     * 中断当前正在进行的推理。
     *
     * 线程安全，可在任意线程调用。
     */
    fun interrupt() {
        interrupted.set(true)
        nativeInterrupt()
    }

    /**
     * 检查模型是否已成功加载。
     *
     * @return true 表示模型已就绪，可以进行推理
     */
    fun isModelLoaded(): Boolean = modelLoaded.get()

    /**
     * 释放模型资源。
     *
     * 在 Activity 销毁或不再需要推理时调用，
     * 释放原生内存中的模型数据。
     */
    fun release() {
        lock.withLock {
            if (modelLoaded.get()) {
                nativeReleaseModel()
                modelLoaded.set(false)
            }
        }
        downloadExecutor.shutdownNow()
    }

    // ==================== 模型下载管理 ====================

    /**
     * 从网络下载 GGUF 模型文件到应用私有目录。
     *
     * 下载过程在后台线程执行，通过回调通知进度与结果。
     * 如果同名文件已存在，会直接返回已有路径而不重复下载。
     *
     * @param url         模型下载地址
     * @param fileName    保存的文件名（例如 "llama-2-7b-chat.Q4_K_M.gguf"）
     * @param onProgress  下载进度回调，参数为 0-100 的进度百分比
     * @param onComplete  下载完成回调，参数为本地文件绝对路径
     * @param onError     下载失败回调，参数为错误描述
     */
    fun downloadModel(
        url: String,
        fileName: String,
        onProgress: (Int) -> Unit = {},
        onComplete: (String) -> Unit = {},
        onError: (String) -> Unit = {}
    ) {
        val targetFile = File(modelsDir, fileName)

        // 文件已存在则直接返回
        if (targetFile.exists() && targetFile.length() > 0) {
            onComplete(targetFile.absolutePath)
            return
        }

        downloadExecutor.execute {
            var connection: HttpURLConnection? = null
            var inputStream: InputStream? = null
            var outputStream: FileOutputStream? = null

            try {
                val urlObj = URL(url)
                connection = urlObj.openConnection() as HttpURLConnection
                connection.connectTimeout = 15000 // 15 秒连接超时
                connection.readTimeout = 60000    // 60 秒读取超时
                connection.instanceFollowRedirects = true

                val statusCode = connection.responseCode
                if (statusCode != HttpURLConnection.HTTP_OK) {
                    onError("服务器返回错误码: $statusCode")
                    return@execute
                }

                val contentLength = connection.contentLength
                inputStream = connection.inputStream

                // 先写入临时文件，下载完成后重命名
                val tempFile = File(modelsDir, "$fileName.tmp")
                outputStream = FileOutputStream(tempFile)

                val buffer = ByteArray(8192) // 8KB 缓冲区
                var bytesRead: Int
                var totalBytesRead: Long = 0

                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                    totalBytesRead += bytesRead

                    // 计算并回调下载进度（百分比）
                    if (contentLength > 0) {
                        val progress = ((totalBytesRead * 100) / contentLength).toInt()
                        onProgress(progress.coerceIn(0, 100))
                    }
                }

                outputStream.flush()
                outputStream.close()
                inputStream.close()
                connection.disconnect()

                // 下载完成，将临时文件重命名为正式文件名
                if (tempFile.renameTo(targetFile)) {
                    onProgress(100)
                    onComplete(targetFile.absolutePath)
                } else {
                    onError("文件重命名失败")
                }

            } catch (e: Exception) {
                android.util.Log.e("LlamaInference", "模型下载失败", e)
                onError("下载失败: ${e.message}")

            } finally {
                // 确保资源释放
                try { outputStream?.close() } catch (_: Exception) {}
                try { inputStream?.close() } catch (_: Exception) {}
                connection?.disconnect()
            }
        }
    }

    /**
     * 获取已下载的模型文件列表。
     *
     * @return 私有模型目录下的所有 .gguf 文件路径
     */
    fun getDownloadedModels(): List<String> {
        return modelsDir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".gguf") }
            ?.map { it.absolutePath }
            ?: emptyList()
    }

    /**
     * 删除指定模型文件。
     *
     * @param modelPath 模型文件路径
     * @return 删除是否成功
     */
    fun deleteModel(modelPath: String): Boolean {
        return File(modelPath).delete()
    }
}
