# 🔷 axi4s-bicubic-upscaler

## 🧩 Introduction

This repository provides a **hardware-optimized bicubic interpolation IP** designed for real-time image scaling on FPGA or ASIC platforms. The core is built on the **AXI4-Stream protocol** and supports full backpressure through `tvalid`, `tready`, `EOL`, and `EOF` signaling. After pipeline warm-up, the design achieves a **sustained throughput of 1 pixel per clock**, enabling seamless integration into high-throughput video pipelines without requiring full-frame buffering.

Unlike runtime-computed bicubic filters, this IP uses a **separable 1D 4-tap kernel model** to precompute 2D interpolation weights for each sub-pixel phase. These weights are stored in a **Q1.15 fixed-point 2D LUT** and accessed at runtime via a compact ROM (`bicubicWeightRom`). For each output pixel, a corresponding **4×4 input window** is prepared by the `imageRearranger_clamp` and `lineBuffer`, and the appropriate 16 weights are applied using a **single-pass 4×4 multiply-accumulate operation**. The core compute block, `BCU_array`, consists of **16 parallel compute units**, each responsible for one pixel in the output 4×4 tile — allowing all 16 results to be calculated simultaneously based on the interpolation phase `(ix, iy ∈ {0..3})`.

The computed pixels are then packed and serialized through a dedicated output pipeline:

bicubicValueBuffer
→ fifo_bram_quad_to_single_axi4s
→ colPixelStream


which ensures proper timing alignment and emits AXI4-Stream output with accurate `EOL` and `EOF` flags. The default configuration implements **4× upscaling** (e.g., `320×180 → 1280×720`) using **four interpolation phases** (`0`, `0.25`, `0.5`, `0.75`), but the architecture can be generalized to other scaling ratios and resolutions.

By offloading all runtime weight evaluation to a **lookup-based structure** and applying **highly pipelined MAC operations**, this IP delivers **high-quality bicubic filtering** while maintaining:
- ✅ Low latency
- ✅ High throughput
- ✅ Resource-efficient implementation

It is ideal for use in:
- 📷 Camera preprocessing
- 🖥️ Display resolution scaling
- 🔍 Super-resolution pipelines
- 🤖 Embedded vision applications requiring real-time performance and minimal distortion
