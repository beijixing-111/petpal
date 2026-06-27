#!/usr/bin/env python3
"""
PetPal 模型量化脚本
将 DeepSeek-LLM-7B-Chat 等模型转换为 GGUF 格式，支持多种量化精度。
基于 llama.cpp 的 convert.py 量化逻辑改造，适用于移动端部署。

用法示例:
    python quantize.py \
        --input-model ./deepseek-7b-fp16.bin \
        --output ./deepseek-7b-q4_0.gguf \
        --quantization q4_0
"""

import argparse
import struct
import sys
from pathlib import Path

import numpy as np

# ============================================================
# GGUF 文件格式常量
# ============================================================

GGUF_MAGIC = 0x46554747  # "GGUF" 魔数
GGUF_VERSION = 3

# 量化类型枚举，对应 GGUF 中的 ggml_type
QUANTIZATION_TYPES = {
    "f16": 1,    # 半精度浮点
    "q4_0": 2,   # 4-bit 量化，无缩放偏移 (推荐用于移动端)
    "q4_1": 3,   # 4-bit 量化，带最小值缩放
    "q5_0": 6,   # 5-bit 量化，无缩放偏移
    "q5_1": 7,   # 5-bit 量化，带最小值缩放
    "q8_0": 8,   # 8-bit 量化 (精度较高，模型较大)
}

# 量化类型的块大小 (block size)
BLOCK_SIZES = {
    "q4_0": 32,
    "q4_1": 32,
    "q5_0": 32,
    "q5_1": 32,
    "q8_0": 32,
}


def parse_args() -> argparse.Namespace:
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="PetPal 模型量化工具 - 将 LLM 模型转换为 GGUF 格式",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--input-model",
        type=Path,
        required=True,
        help="输入模型文件路径（支持 .bin / .safetensors / .pth 格式）"
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="输出 GGUF 文件路径"
    )
    parser.add_argument(
        "--quantization",
        type=str,
        default="q4_0",
        choices=list(QUANTIZATION_TYPES.keys()),
        help="量化精度。推荐 q4_0 (移动端最优，模型小速度快)；"
             "q8_0 (精度较高)；f16 (几乎无损)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="输出详细量化统计信息"
    )
    return parser.parse_args()


def load_model_weights(input_path: Path) -> dict[str, np.ndarray]:
    """
    加载模型权重。
    支持简单的 .bin (numpy 数组) 和 .npz 格式。
    实际使用时可扩展支持 safetensors / PyTorch checkpoint。
    """
    suffix = input_path.suffix.lower()
    tensors: dict[str, np.ndarray] = {}

    if suffix == ".npz":
        # numpy 压缩格式
        data = np.load(input_path)
        for key in data.files:
            tensors[key] = data[key]
            print(f"  加载张量: {key} 形状={tensors[key].shape} 类型={tensors[key].dtype}")
    elif suffix == ".npy":
        # 单个 numpy 数组
        arr = np.load(input_path)
        tensors["model_weights"] = arr
        print(f"  加载张量: model_weights 形状={arr.shape} 类型={arr.dtype}")
    elif suffix in (".bin", ".dat"):
        # 原始二进制文件，按 float32 读取
        raw = input_path.read_bytes()
        arr = np.frombuffer(raw, dtype=np.float32)
        tensors["model_weights"] = arr
        print(f"  加载原始二进制: 共 {len(arr)} 个 float32 值")
    else:
        raise ValueError(f"不支持的模型格式: {suffix}，目前支持 .npz / .npy / .bin")

    return tensors


def quantize_block_q4_0(block: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Q4_0 量化：将 float32 块量化为 4-bit 整数。
    每个块 32 个值共享一个缩放因子 (d)。

    公式: x_q = round(x / d),  其中 d = max(|x|) / 7
    反量化: x ≈ d * x_q

    返回:
        d: 缩放因子 (float16)
        q: 量化值 (int8 打包存储，两个 4-bit 值占 1 字节)
    """
    # 计算缩放因子：将最大绝对值映射到 4-bit 有符号范围 (-8 ~ 7)
    amax = np.max(np.abs(block))
    if amax == 0:
        d = np.float16(1.0)
        q = np.zeros(16, dtype=np.uint8)  # 32 个 4-bit → 16 字节
    else:
        d = np.float16(amax / 7.0)
        # 量化到 [-8, 7] 范围
        q_vals = np.round(block.astype(np.float64) / float(d)).astype(np.int8)
        q_vals = np.clip(q_vals, -8, 7)
        # 打包：每两个 4-bit 值合成一个字节 (低 4-bit 在前)
        q = np.zeros(16, dtype=np.uint8)
        for i in range(16):
            q[i] = (q_vals[2 * i + 1] & 0x0F) << 4 | (q_vals[2 * i] & 0x0F)

    return d, q


def quantize_block_q4_1(block: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Q4_1 量化：带最小值偏移的 4-bit 量化。
    额外存储每个块的最小值，适合范围不对称的权重。

    公式: x_q = round((x - m) / d),  d = (max(x) - min(x)) / 15
    反量化: x ≈ d * x_q + m

    返回:
        d: 缩放因子 (float16)
        m: 最小值 (float16)
        q: 量化值 (uint8 打包)
    """
    x_min = np.min(block)
    x_max = np.max(block)
    delta = x_max - x_min

    if delta == 0:
        d = np.float16(1.0)
        m = np.float16(x_min)
        q = np.zeros(16, dtype=np.uint8)
    else:
        d = np.float16(delta / 15.0)
        m = np.float16(x_min)
        q_vals = np.round(
            (block.astype(np.float64) - float(m)) / float(d)
        ).astype(np.int8)
        q_vals = np.clip(q_vals, 0, 15)
        q = np.zeros(16, dtype=np.uint8)
        for i in range(16):
            q[i] = (q_vals[2 * i + 1] & 0x0F) << 4 | (q_vals[2 * i] & 0x0F)

    return d, m, q


def quantize_block_q5_0(block: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Q5_0 量化：5-bit 量化，无缩放偏移。
    每个块 32 个值共享一个缩放因子和一个 32-bit 高位掩码。

    返回:
        d: 缩放因子 (float16)
        qh: 高位比特掩码 (uint32)
        q: 低位 4-bit 量化值 (uint8 打包)
    """
    amax = np.max(np.abs(block))
    if amax == 0:
        d = np.float16(1.0)
        qh = np.uint32(0)
        q = np.zeros(16, dtype=np.uint8)
    else:
        d = np.float16(amax / 15.0)
        q_vals = np.round(block.astype(np.float64) / float(d)).astype(np.int32)
        q_vals = np.clip(q_vals, -16, 15)

        # 高位比特：第 5 位存到 qh 中
        qh = np.uint32(0)
        for i in range(32):
            if q_vals[i] < 0:
                q_vals[i] += 16
            # 第 4 位（值为 16 表示高位为 1）
            if q_vals[i] >= 16:
                qh |= np.uint32(1 << i)
                q_vals[i] -= 16

        q = np.zeros(16, dtype=np.uint8)
        for i in range(16):
            q[i] = (q_vals[2 * i + 1] & 0x0F) << 4 | (q_vals[2 * i] & 0x0F)

    return d, qh, q


def quantize_block_q8_0(block: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Q8_0 量化：8-bit 量化。
    每个块 32 个值共享一个缩放因子，每个值用 8-bit 存储。

    返回:
        d: 缩放因子 (float16)
        q: 量化值 (int8 数组)
    """
    amax = np.max(np.abs(block))
    if amax == 0:
        d = np.float16(1.0)
        q = np.zeros(32, dtype=np.int8)
    else:
        d = np.float16(amax / 127.0)
        q_vals = np.round(block.astype(np.float64) / float(d)).astype(np.int32)
        q_vals = np.clip(q_vals, -127, 127)
        q = q_vals.astype(np.int8)

    return d, q


def quantize_tensor(
    tensor: np.ndarray, q_type: str, verbose: bool = False
) -> tuple[bytes, int]:
    """
    对整个张量进行分块量化。

    返回:
        data: 量化后的字节数据
        elem_count_out: 输出元素数量（用于 GGUF 元数据）
    """
    block_size = BLOCK_SIZES[q_type]
    flat = tensor.astype(np.float32).ravel()
    total = len(flat)

    # 填充到块大小的整数倍
    pad_len = (block_size - (total % block_size)) % block_size
    if pad_len > 0:
        flat = np.concatenate([flat, np.zeros(pad_len, dtype=np.float32)])

    num_blocks = len(flat) // block_size
    buf = bytearray()

    for b in range(num_blocks):
        block = flat[b * block_size : (b + 1) * block_size]

        if q_type == "q4_0":
            d, q = quantize_block_q4_0(block)
            buf.extend(struct.pack("<e", d))          # float16 缩放因子
            buf.extend(q.tobytes())                     # 16 字节量化数据
        elif q_type == "q4_1":
            d, m, q = quantize_block_q4_1(block)
            buf.extend(struct.pack("<e", d))
            buf.extend(struct.pack("<e", m))
            buf.extend(q.tobytes())
        elif q_type == "q5_0":
            d, qh, q = quantize_block_q5_0(block)
            buf.extend(struct.pack("<e", d))
            buf.extend(struct.pack("<I", qh))           # uint32 高位掩码
            buf.extend(q.tobytes())
        elif q_type == "q5_1":
            d, m, qh, q = quantize_block_q5_1(block)
            buf.extend(struct.pack("<e", d))
            buf.extend(struct.pack("<e", m))
            buf.extend(struct.pack("<I", qh))
            buf.extend(q.tobytes())
        elif q_type == "q8_0":
            d, q = quantize_block_q8_0(block)
            buf.extend(struct.pack("<e", d))            # float16 缩放因子
            buf.extend(q.tobytes())                     # 32 字节量化数据
        elif q_type == "f16":
            # 直接转为 float16，无需分块
            f16_vals = block.astype(np.float16)
            buf.extend(f16_vals.tobytes())

    if verbose:
        orig_bytes = total * 4  # float32
        quant_bytes = len(buf)
        compression = orig_bytes / quant_bytes if quant_bytes > 0 else 0
        print(f"  原始大小: {orig_bytes / 1024 / 1024:.2f} MB  "
              f"→ 量化后: {quant_bytes / 1024 / 1024:.2f} MB  "
              f"(压缩比 {compression:.1f}:1)")

    # f16 每个元素 2 字节，8-bit 每个元素 1 字节
    elem_factor = {"f16": 2, "q4_0": 1, "q4_1": 1, "q5_0": 1, "q5_1": 1, "q8_0": 1}
    return bytes(buf), total


def write_gguf_header(output_path: Path, q_type: str, tensor_info: list[dict]) -> None:
    """
    写入 GGUF 文件头。
    格式: magic(4B) + version(4B) + n_tensors(8B) + n_kv(8B) + metadata_kv
    """
    with open(output_path, "wb") as f:
        # 魔数 + 版本
        f.write(struct.pack("<i", GGUF_MAGIC))
        f.write(struct.pack("<i", GGUF_VERSION))
        # 张量数量和元数据键值对数量
        n_tensors = len(tensor_info)
        f.write(struct.pack("<Q", n_tensors))
        f.write(struct.pack("<Q", 8))  # 固定 8 个元数据项

        # ---- 元数据键值对 ----
        # 1. general.architecture
        write_gguf_string(f, "general.architecture")
        write_gguf_string(f, "deepseek")

        # 2. general.name
        write_gguf_string(f, "general.name")
        write_gguf_string(f, "DeepSeek-LLM-7B-Chat")

        # 3. general.quantization_version
        write_gguf_string(f, "general.quantization_version")
        write_gguf_uint32(f, 2)

        # 4. general.file_type
        write_gguf_string(f, "general.file_type")
        write_gguf_uint32(f, QUANTIZATION_TYPES[q_type])

        # 5. deepseek.block_count
        write_gguf_string(f, "deepseek.block_count")
        write_gguf_uint32(f, 30)

        # 6. deepseek.context_length
        write_gguf_string(f, "deepseek.context_length")
        write_gguf_uint32(f, 4096)

        # 7. deepseek.embedding_length
        write_gguf_string(f, "deepseek.embedding_length")
        write_gguf_uint32(f, 4096)

        # 8. deepseek.feed_forward_length
        write_gguf_string(f, "deepseek.feed_forward_length")
        write_gguf_uint32(f, 11008)

        # ---- 张量信息 ----
        for info in tensor_info:
            write_gguf_string(f, info["name"])
            f.write(struct.pack("<I", len(info["shape"])))  # 维度数
            for dim in info["shape"]:
                f.write(struct.pack("<Q", dim))
            f.write(struct.pack("<I", QUANTIZATION_TYPES[q_type]))
            f.write(struct.pack("<Q", info["offset"]))      # 数据偏移量

        # 对齐到 32 字节
        pos = f.tell()
        align_pad = (32 - (pos % 32)) % 32
        f.write(b"\x00" * align_pad)

        print(f"GGUF 文件头写入完成，元数据偏移: {f.tell()}")


def write_gguf_string(f, s: str) -> None:
    """写入 GGUF 字符串 (长度 + 数据)"""
    encoded = s.encode("utf-8")
    f.write(struct.pack("<Q", len(encoded)))
    f.write(encoded)


def write_gguf_uint32(f, val: int) -> None:
    """写入 GGUF uint32 值 (类型标记 + 数据)"""
    f.write(struct.pack("<I", 4))  # 类型: uint32
    f.write(struct.pack("<I", val))


def quantize_block_q5_1(block: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Q5_1 量化：带最小值偏移的 5-bit 量化。
    类似 q5_0，但额外存储最小值。

    返回:
        d: 缩放因子 (float16)
        m: 最小值 (float16)
        qh: 高位比特掩码 (uint32)
        q: 低位 4-bit 量化值 (uint8 打包)
    """
    x_min = np.min(block)
    x_max = np.max(block)
    delta = x_max - x_min

    if delta == 0:
        d = np.float16(1.0)
        m = np.float16(x_min)
        qh = np.uint32(0)
        q = np.zeros(16, dtype=np.uint8)
    else:
        d = np.float16(delta / 31.0)
        m = np.float16(x_min)
        q_vals = np.round(
            (block.astype(np.float64) - float(m)) / float(d)
        ).astype(np.int32)
        q_vals = np.clip(q_vals, 0, 31)

        qh = np.uint32(0)
        for i in range(32):
            if q_vals[i] >= 16:
                qh |= np.uint32(1 << i)
                q_vals[i] -= 16

        q = np.zeros(16, dtype=np.uint8)
        for i in range(16):
            q[i] = (q_vals[2 * i + 1] & 0x0F) << 4 | (q_vals[2 * i] & 0x0F)

    return d, m, qh, q


def main() -> None:
    """主流程：加载模型 → 量化 → 写入 GGUF 文件"""
    args = parse_args()

    print(f"\n{'='*60}")
    print(f"PetPal 模型量化工具")
    print(f"{'='*60}")
    print(f"输入模型: {args.input_model}")
    print(f"输出文件: {args.output}")
    print(f"量化精度: {args.quantization}")
    print(f"{'='*60}\n")

    # ---- 第 1 步：加载原始模型权重 ----
    print("[1/4] 加载模型权重...")
    tensors = load_model_weights(args.input_model)
    if not tensors:
        print("错误: 未能加载任何模型权重", file=sys.stderr)
        sys.exit(1)
    print(f"  共加载 {len(tensors)} 个张量\n")

    # ---- 第 2 步：逐张量量化 ----
    print(f"[2/4] 量化张量 (类型={args.quantization})...")
    tensor_info: list[dict] = []
    all_data = bytearray()
    current_offset = 0

    for name, tensor in tensors.items():
        print(f"  量化: {name} (形状={tensor.shape})")
        quant_bytes, elem_count = quantize_tensor(
            tensor, args.quantization, verbose=args.verbose
        )

        tensor_info.append({
            "name": name,
            "shape": list(tensor.shape),
            "offset": current_offset,
        })
        current_offset += len(quant_bytes)
        all_data.extend(quant_bytes)

    total_mb = len(all_data) / 1024 / 1024
    print(f"  量化完成，总数据大小: {total_mb:.2f} MB\n")

    # ---- 第 3 步：写入 GGUF 文件头 ----
    print("[3/4] 写入 GGUF 文件头...")
    header_offset = write_gguf_header(args.output, args.quantization, tensor_info)

    # ---- 第 4 步：写入量化数据 ----
    print(f"\n[4/4] 写入量化张量数据...")
    # 更新每个张量的 offset 加上文件头大小
    for info in tensor_info:
        info["offset"] += header_offset

    # 重新写入完整的 GGUF 文件
    write_gguf_header(args.output, args.quantization, tensor_info)
    with open(args.output, "ab") as f:
        f.write(all_data)

    final_size = args.output.stat().st_size / 1024 / 1024
    print(f"\n{'='*60}")
    print(f"量化完成!")
    print(f"输出文件: {args.output}")
    print(f"文件大小: {final_size:.2f} MB")
    print(f"量化精度: {args.quantization}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
