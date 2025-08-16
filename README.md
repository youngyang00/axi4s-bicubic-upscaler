# AXI4S Bicubic Interpolation IP

##  1. Introduction

This repository provides a **hardware-optimized bicubic interpolation IP** designed for real-time image scaling on FPGA or ASIC platforms. The core is built on the **AXI4-Stream protocol** and supports full backpressure through `tvalid`, `tready`, `EOL`, and `EOF` signaling. After pipeline warm-up, the design achieves a **sustained throughput of 1 pixel per clock**, enabling seamless integration into high-throughput video pipelines without requiring full-frame buffering.

Unlike runtime-computed bicubic filters, this IP uses a **separable 1D 4-tap kernel model** to precompute 2D interpolation weights for each sub-pixel phase. These weights are stored in a **Q1.15 fixed-point 2D LUT** and accessed at runtime via a compact ROM (`bicubicWeightRom`). For each output pixel, a corresponding **4×4 input window** is prepared by the `imageRearranger_clamp` and `lineBuffer`, and the appropriate 16 weights are applied using a **single-pass 4×4 multiply-accumulate operation**. The core compute block, `BCU_array`, consists of **16 parallel compute units**, each responsible for one pixel in the output 4×4 tile — allowing all 16 results to be calculated simultaneously based on the interpolation phase `(ix, iy ∈ {0..3})`.

> 🛠️ Notably, this IP **does not use DSP blocks** for multiplication. Instead, all multiply-accumulate operations are implemented using **LUT-based multipliers with a two-stage pipeline**, ensuring consistent timing closure and efficient area usage, even on low-end FPGA devices.

The computed pixels are then packed and serialized through a dedicated output pipeline:

bicubicValueBuffer
→ fifo_bram_quad_to_single_axi4s
→ colPixelStream

which ensures proper timing alignment and emits AXI4-Stream output with accurate `EOL` and `EOF` flags. The default configuration implements **4× upscaling** (e.g., `320×180 → 1280×720`) using **four interpolation phases** (`0`, `0.25`, `0.5`, `0.75`).


<img width="1280" height="413" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/0d7109ab-7017-40d2-9f47-b4984aaefaa7" />

##  2. Architecture
<img width="966" height="379" alt="Archtecture" src="https://github.com/user-attachments/assets/cd84c460-6ea0-4d1e-abf4-4516e8a8030e" />

The Bicubic Resizer accepts an **AXI4-Stream slave** input. The **Rearranger** uses **line buffers (×5)** to assemble a real-time **4×4 pixel window** per cycle (border **clamp**), and the **BCU Array (×16)** applies **phase-indexed 2D weight LUTs (Q1.15)** to perform a **single-pass 4×4 MAC**, generating a **4×4 output tile (16 pixels)** in parallel. The **Back Buffer** then packs and serializes the tile to an **AXI4-Stream master** output at **1 px/clk**, with accurate `EOL/EOF` markers and full `tvalid/tready` backpressure propagation. All multipliers are **LUT-based with a two-stage pipeline**—**no DSP blocks**—for robust timing on low-end FPGAs.

- **Rearranger**: Line-buffer controller that reorders the incoming stream and provides a 4×4 window every cycle (border clamp).
- **BCU Array (×16)**: Each *Bicubic Compute Unit* computes one pixel of the tile using the **16 phase-selected coefficients** and a balanced pipelined adder tree with rounding.
- **Back Buffer**: Packs the 16-pixel tile and serializes to **1 pixel/clock AXI4-Stream**; asserts `EOL/EOF` and propagates backpressure upstream.

## 3. Rearranger — 5-Line Buffer Ring
<img width="1280" height="720" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/ad53c407-ccb8-4983-b549-45834c2f2488" />

The `imageRearranger_clamp.v` and `lineBuffer.v` modules form a **4×4 pixel window every clock cycle** directly from the AXI4-Stream input, without relying on `EOL` or `EOF`.  
**Line switching is driven entirely by internal counters**, and the EOL/EOF flags are handled separately in the **Back Buffer / colPixelStream** stage.

### Per-pixel operation
1. **Write path**: The incoming pixel (RGB24 packed in 32b) is written into the **WRITE bank** at column `x`, which increments from `0` to `W−1`.
2. **Read path**: Four **READ banks** are accessed at column offsets `{x−1, x, x+1, x+2}` (clamped at borders).  
   Each row produces 4 pixels, forming the full **4×4 neighborhood**.
3. **Output**: The 16 pixels (4 rows × 4 columns) are packed into `o_pixel_data_{r,g,b}[127:0]` and sent to the `BCU_array`.  
   The `o_pixel_data_valid` signal is asserted when the window is ready.
4. **Backpressure handling**: If downstream `tready = 0`, the write enable and address counters stall, maintaining window consistency.

### Line buffer rotation
When the horizontal counter wraps from `x == W−1` to `0`, the module performs a **line buffer role rotation**:
- The current **WRITE** bank becomes the **bottom-most READ** bank,
- The oldest READ bank is reused as the new **WRITE** bank.

No data is copied — only pointers are swapped. This ensures smooth line transitions without stalling the pipeline.

### Why 5 line buffers?
- Bicubic filtering needs **4 vertical lines** per output pixel.
- The 5th line allows us to **write the next row concurrently** while reading the current 4,  
  eliminating read-write contention and keeping **1 px/clk** throughput.
## 4. BCU Array

### 1) Micro-architecture of a Single BCU
<img width="1280" height="720" alt="BCU_Arc" src="https://github.com/user-attachments/assets/80b2bf41-1628-4ff9-bcf2-c88453347832" />

Each **Bicubic Compute Unit (BCU)** is responsible for generating a single RGB pixel using a **4×4 input window** and **phase-specific interpolation weights**.  
The unit is fully pipelined, enabling **one output pixel per clock** once the pipeline is primed.

- **Inputs**: `Pixels_16Packed(R/G/B)` — 16 pixels per channel (128 bits each)  
- **Weight ROM**: Provides 16 signed **Q1.15 coefficients**, unique to each unit’s assigned phase `(ix, iy)`  
- **Kernel Calculators (per channel)**:
  - 16 × **LUT-based multipliers** (2-stage pipeline, no DSP usage)
  - **Pipelined adder tree** followed by rounding to 8-bit
- **Output**: One 24-bit RGB pixel per BCU

All 16 BCUs operate in parallel within the array.

---

### 2) Phase-specific Kernel Application
<img width="1280" height="720" alt="3" src="https://github.com/user-attachments/assets/3dd9aa4a-dfd1-47ea-b901-b6de71baa9d9" />
Although all BCUs receive the **same 4×4 input window**, each applies a **different set of precomputed interpolation weights** according to its assigned **output sub-pixel phase** `(ix, iy ∈ {0,1,2,3})`.  
This allows all **16 sub-pixel positions** of a 4×4 output tile to be computed in parallel.

For each color channel \(c\):

For each color channel c:
    acc_c = ∑(j=0 to 3) ∑(i=0 to 3) P_c[j][i] * W_{ix,iy}[j][i]
    out_c = round(acc_c)

Where:
    P_c[j][i] = 8-bit input pixel at row j, col i, for channel c
    W_{ix,iy}[j][i] = Q1.15 kernel weight for phase (ix, iy)


Each BCU produces one RGB output pixel for its assigned tile location.  
The **16 results are spatially aligned** to form a complete 4×4 tile.

---

### 3) Tile-wise Execution over the Input Stream

<img width="1280" height="720" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/18438425-989e-4295-a640-f314f820b830" />

Each valid input window from the Rearranger corresponds to a single **4×4 output tile** produced by the `BCU_array`.  
The array performs **tile-wise bicubic interpolation**, where a fixed 4×4 input patch is mapped into 16 output pixels — one per compute unit — using a unique interpolation phase `(ix, iy)` per unit.

For a 4× upscale, the mapping from input pixel to output tile is defined as:

- For an input anchor coordinate `(x, y)`,  
  the top-left of the output tile is located at `(X0, Y0) = (4×x, 4×y)`
- Each compute unit calculates one pixel at position:  
  `X = X0 + ix`, `Y = Y0 + iy`  
  where `(ix, iy) ∈ {0, 1, 2, 3}`

As the 4×4 input window slides horizontally or vertically:

- A single step in **x** shifts the tile by 4 pixels to the right  
- A single step in **y** shifts the tile by 4 pixels downward  
- Output tiles are placed **contiguously** — no overlap, no gaps

---
## 5. Back Buffer — Output Tile Packing & Serialization
<img width="1280" height="455" alt="프레젠테이션1" src="https://github.com/user-attachments/assets/c08e3fa6-d586-43d6-8a0d-e9b36e22d851" />

The **Back Buffer** module transforms the parallel 4×4 RGB tile output from the `BCU_array` into a serialized AXI4-Stream output, emitting one pixel per clock. This process ensures smooth downstream transfer with full timing alignment and backpressure support.

### Data Flow Overview

#### 🔹 Output pixels (Packed)

- Each `BCU` generates one RGB pixel (24 bits).
- All 16 pixels from the array are delivered in a single cycle as three 128-bit vectors:
  - `r_tile[127:0]`, `g_tile[127:0]`, `b_tile[127:0]`

#### 🔹 Tile → Row Bursts (4 px/beat)

- The **`bicubicValueBuffer`** module groups the 4×4 tile into **row bursts**:
  - 4 rows × 4 pixels → 4 beats
  - Each beat holds 4 RGB pixels = 96 bits (4 × 24b)

- This representation is used to efficiently write to the internal **BRAM FIFO**.

#### 🔹 Quad → Single Serializer

- The **`fifo_bram_quad_to_single_axi4s`** reads back one beat at a time and serializes the 4 pixels.
- The **`colPixelStream`** module then:
  - Emits 1 pixel per cycle (`tdata`)
  - Asserts `tvalid`, accepts `tready`
  - Inserts appropriate `EOL` and `EOF` signals based on pixel location

---

## 6. Timing and Resource Utilization

The `axi4s-bicubic-upscaler` IP was synthesized using **Vivado Design Suite**, targeting the **Zynq UltraScale+ ZCU102** evaluation board.  
The design achieved full timing closure at **300 MHz**, ensuring reliable operation for real-time high-throughput video processing.

### 🔧 Timing Summary

All timing constraints were met successfully:

| Metric                     | Value     |
|----------------------------|-----------|
| Worst Negative Slack (WNS) | 0.092 ns  |
| Worst Hold Slack (WHS)     | 0.010 ns  |
| Worst Pulse Width Slack    | 1.124 ns  |
| Total Failing Endpoints    | 0         |

> ✅ **All user-specified timing constraints are met at 300 MHz.**  
> The fully pipelined architecture — including **LUT-based multipliers** — ensures stable performance without requiring DSP blocks.

---

### 📊 Resource Utilization (ZCU102)

| Resource | Utilization | Available | Utilization % |
|----------|-------------|-----------|----------------|
| LUT      | 45,373      | 274,080   | 16.55%         |
| LUTRAM   | 7,783       | 144,000   | 5.40%          |
| FF       | 38,374      | 548,160   | 7.00%          |
| BRAM     | 27.5        | 912       | 3.02%          |
| IO       | 64          | 328       | 19.51%         |
| BUFG     | 1           | 404       | 0.25%          |

This efficient implementation consumes less than **20% of LUTs** and only **~3% of BRAMs**, making it highly suitable for integration into larger image processing pipelines.

---

### 🚀 Measured Throughput

- Target Resolution: **320×180 → 1280×720 (4× upscale)**
- Clock Frequency: **300 MHz**
- AXI4-Stream Output Rate: **1 pixel/clock**
- **Measured Throughput**:  
  **≈ 3.93 frames/sec** at full-resolution output (1280×720)

> The current design demonstrates stable streaming output with **3.93 fps** at 300 MHz, proving functional correctness and architectural scalability. For production use, higher frame rates can be achieved through deeper pipelining, resource duplication, or integration into multi-channel video pipelines.

