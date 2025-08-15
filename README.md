# 🔷 axi4s-bicubic-upscaler

##  Introduction

This repository provides a **hardware-optimized bicubic interpolation IP** designed for real-time image scaling on FPGA or ASIC platforms. The core is built on the **AXI4-Stream protocol** and supports full backpressure through `tvalid`, `tready`, `EOL`, and `EOF` signaling. After pipeline warm-up, the design achieves a **sustained throughput of 1 pixel per clock**, enabling seamless integration into high-throughput video pipelines without requiring full-frame buffering.

Unlike runtime-computed bicubic filters, this IP uses a **separable 1D 4-tap kernel model** to precompute 2D interpolation weights for each sub-pixel phase. These weights are stored in a **Q1.15 fixed-point 2D LUT** and accessed at runtime via a compact ROM (`bicubicWeightRom`). For each output pixel, a corresponding **4×4 input window** is prepared by the `imageRearranger_clamp` and `lineBuffer`, and the appropriate 16 weights are applied using a **single-pass 4×4 multiply-accumulate operation**. The core compute block, `BCU_array`, consists of **16 parallel compute units**, each responsible for one pixel in the output 4×4 tile — allowing all 16 results to be calculated simultaneously based on the interpolation phase `(ix, iy ∈ {0..3})`.

> 🛠️ Notably, this IP **does not use DSP blocks** for multiplication. Instead, all multiply-accumulate operations are implemented using **LUT-based multipliers with a two-stage pipeline**, ensuring consistent timing closure and efficient area usage, even on low-end FPGA devices.

The computed pixels are then packed and serialized through a dedicated output pipeline:

bicubicValueBuffer
→ fifo_bram_quad_to_single_axi4s
→ colPixelStream

which ensures proper timing alignment and emits AXI4-Stream output with accurate `EOL` and `EOF` flags. The default configuration implements **4× upscaling** (e.g., `320×180 → 1280×720`) using **four interpolation phases** (`0`, `0.25`, `0.5`, `0.75`).


<img width="1280" height="413" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/0d7109ab-7017-40d2-9f47-b4984aaefaa7" />

##  Architecture
<img width="966" height="379" alt="Archtecture" src="https://github.com/user-attachments/assets/cd84c460-6ea0-4d1e-abf4-4516e8a8030e" />

The Bicubic Resizer accepts an **AXI4-Stream slave** input. The **Rearranger** uses **line buffers (×5)** to assemble a real-time **4×4 pixel window** per cycle (border **clamp**), and the **BCU Array (×16)** applies **phase-indexed 2D weight LUTs (Q1.15)** to perform a **single-pass 4×4 MAC**, generating a **4×4 output tile (16 pixels)** in parallel. The **Back Buffer** then packs and serializes the tile to an **AXI4-Stream master** output at **1 px/clk**, with accurate `EOL/EOF` markers and full `tvalid/tready` backpressure propagation. All multipliers are **LUT-based with a two-stage pipeline**—**no DSP blocks**—for robust timing on low-end FPGAs.

- **Rearranger**: Line-buffer controller that reorders the incoming stream and provides a 4×4 window every cycle (border clamp).
- **BCU Array (×16)**: Each *Bicubic Compute Unit* computes one pixel of the tile using the **16 phase-selected coefficients** and a balanced pipelined adder tree with rounding.
- **Back Buffer**: Packs the 16-pixel tile and serializes to **1 pixel/clock AXI4-Stream**; asserts `EOL/EOF` and propagates backpressure upstream.

## 🔄 Rearranger — 5-Line Buffer Ring (matches the RTL)
<img width="1280" height="720" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/ad53c407-ccb8-4983-b549-45834c2f2488" />

The rearranger in `imageRearranger_clamp.v` + `lineBuffer.v` forms a **4×4 window every clock** from a streaming AXI4-Stream input.  
It uses **five dual-port line buffers** arranged as a ring:

- **Four banks = READ rows** for the current window (y−1…y+2).
- **One bank = WRITE row** that captures the next incoming line (y+3).
- On each `EOL`, roles **rotate by pointer swap** (no data copy).

### Per-pixel operation
1. **Write:** the incoming pixel (RGB24 in 32b) is written to the **WRITE bank** at column `x`.
2. **Read:** the four **READ banks** are addressed at columns `{x−1, x, x+1, x+2}`  
   (addresses are **clamped** at borders), delivering 4 samples/row.
3. **Assemble 4×4:** each row feeds a small 4-tap shift (or register slice), so the four rows
   produce **16 pixels/clk** → issued as `{R,G,B}[127:0]` toward `BCU_array`.
4. **Handshake aware:** when downstream back-pressure de-asserts `tready`, **addresses and
   shift registers hold**; the write port is also stalled, so windows remain coherent.

### Line rotation (per EOL)
At the end of a line:
- `WRITE` bank becomes the **new bottom READ** bank,
- the oldest READ bank is recycled to **WRITE**,
- column counters reset; line counter increments.
This avoids read/write conflicts while sustaining **1 px/clk** across line boundaries.

### Border handling
- **Left/Top:** replicate the first valid sample (addr = 0).
- **Right/Bottom:** replicate the last valid sample (addr = W−1 / H−1).
- Windows are valid **from the very first output**; no bubbles.

**Why 5 banks?** Bicubic needs **4 vertical rows** each cycle. The extra bank allows us to
**capture the next line concurrently** with reading the current 4 rows, eliminating hazards at EOL and keeping the compute array fed continuously.

**Output to compute:** the rearranger asserts `o_pixel_data_valid` with packed
`o_pixel_data_{r,g,b}[127:0]` (16×8-bit per channel), exactly matching the inputs expected by `BCU_array` and the downstream value buffer.
