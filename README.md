#   4×4 Pipelined Multiplier — RTL to GDSII Flow

Complete ASIC design flow: RTL → Verification → Synthesis → Floorplan → CTS → Routing → Signoff.

---

# 1. Project Overview

The **4×4 Pipelined Multiplier (RTL → GDSII)** project demonstrates a complete end-to-end VLSI design flow, starting from RTL Verilog design and progressing all the way to signoff-level physical implementation using industry-standard tools such as:

- Cadence Genus (logic synthesis)
- Cadence Innovus (physical design, routing & signoff)
- NCLaunch (simulation & verification)

This project implements a **3-stage pipelined 4-bit × 4-bit multiplier**, optimized for high throughput. By pipelining the multiplier, new inputs are accepted every clock cycle while previous operations propagate through the stages. This significantly increases performance compared to a purely combinational multiplier.

---

# Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. RTL Design](#2-rtl-design)
- [3. Testbench and Verification (NCLaunch)](#3-testbench-and-verification-nclaunch)
- [4. Synthesis (Cadence Genus)](#4-synthesis-cadence-genus)
  - [4.1 SDC File Explanation](#sdc-file-timing-constraints-used-in-synthesis)
- [5. Physical Design (Cadence Innovus)](#5-physical-design-cadence-innovus)
  - [5.1 Floorplan](#51-floorplan)
  - [5.2 Power Planning (Rings-Stripes-SRoute)](#52-power-planning-rings-stripes-sroute)
  - [5.3 Placement (Standard--Physical Cells)](#53-placement-standard--physical-cells)
  - [5.4 Clock Tree Synthesis (CTS)](#54-clock-tree-synthesis-cts)
  - [5.5 Routing (NanoRoute)](#55-routing-nanoroute)
  - [5.6 Timing Analysis and ECO](#56-timing-analysis-and-eco-engineering-change-order)
  - [5.7 RC Extraction and SDF Generation](#57-rc-extraction-corner-analysis-and-sdf-generation)
  - [5.8 DRC, Connectivity, Final Netlist, Save ENC](#58-drc-connectivity-checks-final-netlist-and-innovus-database-save)
- [6. Conclusion](#6-conclusion)


## Project Objectives

- Design a fully synchronous, 3-stage pipelined 4×4 multiplier in Verilog RTL.
- Build a self-checking testbench and simulate using NCLaunch for functional verification.
- Synthesize the design using Cadence Genus, generating:
  - Gate-level netlist
  - Timing report
  - Area report
  - Power report
- Perform complete physical design in Cadence Innovus, covering:
  - Floorplan
  - Power planning (rings and stripes)
  - Standard cell placement and physical-only cells
  - Clock Tree Synthesis (CTS)
  - Global & detailed routing (NanoRoute)
  - Post-route ECO fixes
  - RC Extraction (best and worst cases)
  - Final timing closure
- Generate signoff files:
  - Post-route netlist
  - SDF files (func_slow_max.sdf, func_fast_min.sdf)
  - DRC & connectivity-clean layout
  - Saved Innovus database (.enc)

---

## Why Pipelining?

A normal 4×4 multiplier produces output only after full combinational delay.  
A pipelined multiplier breaks the operation into:

1. Partial Product Generation  
2. Intermediate Addition  
3. Final Addition + Output Register  

Benefits include:

- Higher maximum operating frequency  
- Higher throughput (1 result per cycle)  
- Easier timing closure in synthesis & PnR  
- Better scalability for larger multipliers  

---

## RTL to GDSII Flow Summary

This project follows a real-world ASIC flow:

1. RTL Design  
2. Testbench & Functional Verification  
3. Logic Synthesis (Genus)  
4. Physical Design (Innovus)  
5. Timing Closure & Signoff  
6. Post-route Netlist + SDF Generation  
7. Innovus .enc Database Save  

---

## Tools Used

| Stage | Tool | Purpose |
|-------|------|---------|
| RTL Simulation | NCLaunch | Functional simulation |
| Synthesis | Cadence Genus | Logic synthesis; timing/area/power analysis |
| Physical Design | Cadence Innovus | Floorplan → Placement → CTS → Routing |

---

# 2. RTL Design

The RTL implementation of the 4×4 pipelined multiplier is structured into **three sequential pipeline stages**, each separated by registers. This improves throughput, maximizes clock frequency, and simplifies timing closure during synthesis and physical design. The design is fully synchronous with an active-low reset (`rst_n`).

This section includes the complete RTL code, a detailed breakdown of each stage, and ASCII diagrams showing the pipeline architecture.

---

## Complete RTL Code

```verilog
/*
 * 3-Stage 4x4 Pipelined Multiplier
 * Stage 1: Partial Product Registers (pp0-pp3)
 * Stage 2: Partial Sum Registers (s1_a, s1_b)
 * Stage 3: Final Product Register (P)
 */
`timescale 1ns/1ps

module mult4x4_pipelined (
    input  wire       clk,
    input  wire       rst_n, // Active-low reset
    input  wire [3:0] A,
    input  wire [3:0] B,
    output reg  [7:0] P      // Pipelined output
);

    // --- STAGE 1 Registers: Partial Products ---
    reg [3:0] pp0, pp1, pp2, pp3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pp0 <= 4'd0;
            pp1 <= 4'd0;
            pp2 <= 4'd0;
            pp3 <= 4'd0;
        end else begin
            // Combinational logic for Stage 1:
            pp0 <= A & {4{B[0]}}; // A * B[0]
            pp1 <= A & {4{B[1]}}; // A * B[1]
            pp2 <= A & {4{B[2]}}; // A * B[2]
            pp3 <= A & {4{B[3]}}; // A * B[3]
        end
    end

    // --- STAGE 2 Registers: Partial Sums ---
    reg [5:0] s1_a; // Max: (15) + (15<<1) = 45
    reg [7:0] s1_b; // Max: (15<<2) + (15<<3) = 180

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_a <= 6'd0;
            s1_b <= 8'd0;
        end else begin
            // Combinational logic for Stage 2:
            s1_a <= {2'b00, pp0} + {1'b0, pp1, 1'b0};
            s1_b <= {pp2, 2'b00} + {pp3, 3'b000};
        end
    end

    // --- STAGE 3 Register: Final Product ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P <= 8'd0;
        end else begin
            // Combinational logic for Stage 3:
            P <= s1_a + s1_b;
        end
    end

endmodule
```

---

## Stage-Wise Detailed Diagram

```
---------------------------------------------------------------
|                           Stage 1                           |
|                Partial Product Computation                  |
|                                                             |
|   pp0 = A & {4{B[0]}}                                       |
|   pp1 = A & {4{B[1]}}                                       |
|   pp2 = A & {4{B[2]}}                                       |
|   pp3 = A & {4{B[3]}}                                       |
|                                                             |
|   Outputs: pp0[3:0], pp1[3:0], pp2[3:0], pp3[3:0]           |
---------------------------------------------------------------
                                │
                                ▼
---------------------------------------------------------------
|                           Stage 2                           |
|               Intermediate Partial Sum Logic                |
|                                                             |
|   s1_a = pp0 + (pp1 << 1)                                   |
|   s1_b = (pp2 << 2) + (pp3 << 3)                            |
|                                                             |
|   Outputs: s1_a[5:0], s1_b[7:0]                             |
---------------------------------------------------------------
                                │
                                ▼
---------------------------------------------------------------
|                           Stage 3                           |
|                  Final Addition + Output Reg                |
|                                                             |
|   P = s1_a + s1_b                                           |
|                                                             |
|   Output: P[7:0]  (Final 8-bit product)                     |
---------------------------------------------------------------
```

---

## RTL Explanation

### Overview
The 4×4 multiplication (`A × B`) is decomposed into bitwise partial products and accumulated through a **three-stage pipeline**. Each pipeline stage performs a small portion of the work and stores results in registers.

This reduces combinational depth and enables one output every clock cycle after the pipeline fills.

---

## Stage 1: Partial Product Generation

### Purpose
Produce four 4-bit partial products using bitwise AND:

- `pp0 = A × (B[0])`
- `pp1 = A × (B[1] << 1)`
- `pp2 = A × (B[2] << 2)`
- `pp3 = A × (B[3] << 3)`

### Notes
- The AND + replication `{4{B[i]}}` implements multiplication by each bit.
- All values are stored in registers to form pipeline Stage 1.

---

## Stage 2: Partial Sum Accumulation

### Purpose
Combine partial products into two intermediate sums:

```
s1_a = pp0 + (pp1 << 1)
s1_b = (pp2 << 2) + (pp3 << 3)
```

### Why split into two sums?
- Reduces logic depth  
- Improves timing  
- Allows clean pipelining before final addition  

---

## Stage 3: Final Product Computation

The final output is produced by adding both partial sums:

```
P = s1_a + s1_b
```

`P` is stored in a register, completing the 3-stage pipeline.

---

## Pipeline Latency and Throughput

- **Latency:** 3 clock cycles  
- **Throughput:** 1 product per cycle after pipeline is full  
- **Clock Frequency:** Higher than non-pipelined version due to reduced logic depth per stage  

---
# 3. Testbench and Verification (NCLaunch)

The functionality of the 4×4 pipelined multiplier was verified using a directed-testbench and waveforms generated through **Cadence NCLaunch**. The testbench applies several input combinations sequentially and observes the 3-cycle pipelined behavior at the output.

---

## Complete Testbench Code

```verilog
`timescale 1ns/1ps

module tb_mult4x4_pipelined;

    reg clk;
    reg rst_n;
    reg [3:0] A, B;
    wire [7:0] P;

    // DUT instantiation
    mult4x4_pipelined dut (
        .clk(clk),
        .rst_n(rst_n),
        .A(A),
        .B(B),
        .P(P)
    );

    // Clock generation (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // --------------------------
        // RESET
        // --------------------------
        rst_n = 0;
        A = 4'd0;
        B = 4'd0;
        #20;           // hold reset for 2 cycles
        rst_n = 1;

        // --------------------------
        // APPLY SIMPLE TEST VECTORS
        // --------------------------
        
        // Cycle 1
        @(posedge clk);
        A = 4'd3; B = 4'd2;   // Expect 6 → appears after 3 cycles

        // Cycle 2
        @(posedge clk);
        A = 4'd7; B = 4'd4;   // Expect 28

        // Cycle 3
        @(posedge clk);
        A = 4'd9; B = 4'd3;   // Expect 27

        // Cycle 4
        @(posedge clk);
        A = 4'd15; B = 4'd15; // Expect 225

        // Cycle 5
        @(posedge clk);
        A = 4'd6; B = 4'd8;   // Expect 48

        // Hold inputs stable
        @(posedge clk);
        A = 4'd0; B = 4'd0;

        // Allow waveform to finish
        #200;

        $finish;
    end

endmodule
```

---

## Verification Flow in NCLaunch

### 1. Compilation
NCLaunch compiles all RTL and testbench files and checks for syntax errors, missing modules, and data-type consistency.

### 2. Elaboration
NCLaunch builds the complete design hierarchy, connects the DUT and testbench, resolves parameters, and prepares the simulation snapshot.

### 3. Simulation
The simulation is run on the elaborated snapshot. Waveforms are generated and can be viewed directly inside NCLaunch to verify pipeline behavior.

---

## Expected Pipeline Behavior

The multiplier has **3 pipeline stages**, so an input applied at clock cycle *N* appears at the output at cycle *N + 3*.

| Input Cycle | A | B | Expected Output | Output Cycle |
|-------------|---|---|-----------------|--------------|
| Cycle 1 | 3  | 2  | 6   | Cycle 4 |
| Cycle 2 | 7  | 4  | 28  | Cycle 5 |
| Cycle 3 | 9  | 3  | 27  | Cycle 6 |
| Cycle 4 | 15 | 15 | 225 | Cycle 7 |
| Cycle 5 | 6  | 8  | 48  | Cycle 8 |

---

## Observations from NCLaunch Simulation
<img width="1920" height="1080" alt="Screenshot 2025-11-14 132353" src="https://github.com/user-attachments/assets/963da398-cefa-4646-89f5-ed10e486ac60" />


- The reset behavior is correct; all registers initialize to zero.
- No output appears during the first 3 cycles as the pipeline is filling.
- The first valid output (`6`) appears exactly 3 cycles after the first input.
- A new output is produced every subsequent cycle, proving correct pipelining.
- All output values match the expected arithmetic results.
- Waveforms clearly show Stage 1 → Stage 2 → Stage 3 propagation.

---

## Verification Summary

- Design compiles and elaborates cleanly in NCLaunch  
- Pipeline output matches expected results  
- Correct 3-cycle latency observed  
- One result produced every clock cycle after pipeline fill  
- The design is fully functionally verified and ready for synthesis

---

# 4. Synthesis (Cadence Genus)

The RTL design of the 4×4 pipelined multiplier was synthesized using **Cadence Genus**. Synthesis converts the Verilog RTL into a **gate-level netlist** mapped to a specific standard-cell library, ensuring the design meets timing, area, and power requirements before moving into physical design.

---

## What Synthesis Does

During synthesis, Genus performs:

### 1. RTL Analysis and Elaboration
- Reads the Verilog RTL  
- Builds the design hierarchy  
- Checks for width mismatches, undriven nets, and inferred latches  

### 2. Technology Mapping
- Converts RTL operations into library cells  
- Uses NAND, NOR, XOR, MUX, adders, DFFs, buffers, etc.  
- Selects gate drive strengths based on timing  

### 3. Timing, Area, and Power Optimization
- Fixes setup violations  
- Reduces total cell area  
- Minimizes switching activity and internal power  
- Performs logic restructuring, buffering, and replication  

### 4. Netlist Generation
Produces a gate-level Verilog file containing:
- Standard cells only  
- Flip-flops, combinational logic, buffers  
- No behavioral constructs  

This synthesized netlist becomes the input to Cadence Innovus for physical design.

---

# SDC File (Timing Constraints Used in Synthesis)

Synthesis is driven by the **SDC (Synopsys Design Constraints)** file.  
The SDC defines all timing-related requirements for the design and informs Genus about how the circuit must behave under real hardware conditions.

### Why the SDC is Important

The SDC file tells Genus:
- What the **clock frequency** is  
- How much margin to keep (skew, jitter)  
- How early/late inputs may arrive  
- How heavily outputs are loaded  
- Which signals are synchronous vs. asynchronous  
- Maximum allowed transition, fanout, and capacitance  
- Which paths should be ignored (false paths)  

Correct SDC = correct, realistic synthesis.

---

## Complete SDC File Used

```tcl

create_clock -name clk -period 5.000 [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]
set_input_delay 1.0 -clock clk [get_ports {A[*]}]
set_input_delay 1.0 -clock clk [get_ports {B[*]}]
set_input_delay 0.0 -clock clk [get_ports rst_n]
set_output_delay 1.0 -clock clk [get_ports {P[*]}]
set_false_path -from [get_ports rst_n]
set_max_transition 0.10 [current_design]
set_max_fanout 10 [current_design]
set_max_capacitance 0.30 [current_design]
set_load 0.02 [get_ports {P[*]}]


```

---

## Explanation of Key SDC Sections

### 1. Clock Definition
Defines a **5 ns period clock (200 MHz)**:
- Enables Genus to compute timing requirements  
- Used for setup and hold analysis  

`set_clock_uncertainty` adds margin for skew + jitter.

---

### 2. Input Delays  
Defines how late external signals may arrive relative to the clock.  
Assumes inputs A and B come from another synchronous block.

---

### 3. Output Delays  
Defines how much time is available for the output `P` to reach the next stage.

---

### 4. False Path  
The asynchronous reset (`rst_n`) bypasses timing checks.

---

### 5. Design Rule Constraints  
Constrains:
- Maximum transition  
- Maximum allowed load  
- Maximum fanout  

These ensure realistic cell selection and reduce timing violations later.

---

### 6. Output Load  
Models the capacitance at output pins (important for timing accuracy).

---

## Synthesis Outputs

### 1. Timing Report
<img width="1016" height="632" alt="Screenshot 2025-11-19 115407" src="https://github.com/user-attachments/assets/6a9dfd53-8545-4fc6-9d19-b483d346117a" />

<img width="1171" height="494" alt="Screenshot 2025-11-19 115422" src="https://github.com/user-attachments/assets/ad152aa2-cce6-4552-b8d6-3b8b9b5f457c" />

### 2. Area Report
<img width="1470" height="288" alt="Screenshot 2025-11-19 115540" src="https://github.com/user-attachments/assets/b52efd83-c8a1-4c40-9415-69adccf54e5d" />

### 3. Power Report
<img width="1165" height="345" alt="Screenshot 2025-11-19 115603" src="https://github.com/user-attachments/assets/2c05df78-3642-48fb-bda8-f45ecfe18902" />

### 4. QoR Report
<img width="903" height="784" alt="Screenshot 2025-11-19 120244" src="https://github.com/user-attachments/assets/f566f75c-3c58-4899-843c-4f3b438b2a1c" />

### 5. Gate-Level Netlist
<img width="1920" height="1080" alt="Screenshot 2025-11-14 134000" src="https://github.com/user-attachments/assets/392d4069-048d-4339-b325-f342fbbf0ba3" />


## Synthesis Summary

- RTL synthesized successfully with Cadence Genus  
- Timing constraints defined using SDC were met  
- Area and power results generated  
- No violations after optimization  
- Netlist ready for import into Innovus  

---

# 5. Physical Design (Cadence Innovus)

## 5.1 Floorplan

The first stage of physical design is floorplanning, where we define the **core area**, **aspect ratio**, **core margins**, and **cell utilization**. These values directly influence the routability, timing, congestion, and eventual size of the chip/block.

The following values were used during the floorplan setup in Cadence Innovus:

---

## Floorplan Values

<img width="1920" height="1080" alt="Screenshot 2025-11-19 120654" src="https://github.com/user-attachments/assets/77ef872f-71d7-43cd-a94e-9ee23bace2b9" />


---

## Why These Values Were Chosen

### 1. **Aspect Ratio = 1**
A square core minimizes:
- Routing hotspots  
- Timing imbalance between horizontal/vertical paths  
- Skew during CTS  

It is the most stable shape for small/medium digital blocks.

---

### 2. **Core Utilization = 60%**
A typical recommended range is **50%–70%**.

Reasons for choosing **60%**:
- Leaves enough whitespace for routing  
- Allows space for CTS buffers and legalization  
- Prevents routing congestion  
- Prevents timing violations due to detours  

Higher utilization (>75%) is risky and causes:
- Congestion  
- DRC violations  
- Long wires + poor timing  

---

### 3. **Core Dimensions ~30 µm × 27 µm**
These values are automatically computed based on:
- Total cell area reported by Genus  
- Target utilization of 60%  
- Aspect ratio = 1  

Because the design is small (pipelined 4×4 multiplier):
- Only a few standard cells  
- Small core area  
- Dimension in tens of microns is expected for 45nm tech  

---

### 4. **Margins = 15 µm (Left, Right, Top, Bottom)**
Core margins ensure:
- Enough space for **power rings (VDD/VSS)**  
- Routing channels for global signals  
- Placement of physical-only cells (e.g., well taps, endcaps)  
- IO routing without congestion  

15 µm margins are very common for:
- Small to medium blocks  
- 45nm tech nodes  

---

### 5. **IO Box: Max IO Height**
This ensures:
- IO cells will not overlap  
- Tallest IO cell determines IO row height  

Since this is a core-only block, IO handling is minimal, but setting this correctly ensures layout consistency.

---

## 5.2 Power Planning (Rings, Stripes, SRoute)

Power planning ensures that the design receives a stable and uniform power supply (VDD/VSS). For this block, power planning was performed using three steps:

1. **Power Rings** (around core boundary)  
2. **Power Stripes** (inside core area)  
3. **Special Routing (SRoute)** to connect rings, stripes, and std. cell rails  

These ensure low IR-drop, clean current distribution, and reliable operation.

---

# 5.2.1 Power Rings

The following configuration was used for the power rings around the core:

<img width="1919" height="1003" alt="Screenshot 2025-11-19 120808" src="https://github.com/user-attachments/assets/f45e79f8-0e22-4a3a-bb1e-e85be74ff67c" />

---

### Why These Values Were Chosen

#### 1. **Metal3 (horizontal) and Metal4 (vertical)**
This is a standard practice:
- Use alternating horizontal and vertical layers  
- Metal3 and Metal4 are thick enough to carry power  
- Avoids congestion in lower signal-carrying layers (M1, M2)

#### 2. **Ring Width = 1.2 µm**
Typical for small blocks in 45nm.
- Wide enough to carry current with low IR drop  
- Not excessively large (which would waste area)

If ring width is too small:
- Higher IR drop  
- Potential electromigration problems  

If too large:
- Wasted routing resources  
- Increased area unnecessarily  

#### 3. **Spacing = 1 µm**
Provides:
- Separation between VDD and VSS rings  
- Enough room to route vias safely  
- Meets DRC rules

#### 4. **Offset = 2 µm**
Keeps rings slightly away from core edge:
- Prevents DRC violations  
- Allows routing resources between ring and core boundary  
- Ensures clearance for IO pins (if any)

---

# 5.2.2 Power Stripes (Vertical/Horizontal)

The stripe configuration used:


<img width="1919" height="992" alt="Screenshot 2025-11-19 132235" src="https://github.com/user-attachments/assets/9773898c-8d6d-486f-8ed8-63b460aa5fd5" />

---

### Why These Stripe Values Were Chosen

#### 1. **Metal4 for Stripes**
- Thick layer → lower resistance  
- Less congested than lower metals  
- Good for power distribution across rows  

#### 2. **Width = 0.5 µm**
A typical stripe width for 45nm:
- Sufficient current-carrying capability  
- Avoids excessive metal usage  

#### 3. **Spacing = 0.5 µm**
This ensures:
- VDD and VSS stripes alternate cleanly  
- Enough isolation to prevent shorts  
- Good routing channels between stripes  

#### 4. **Set-to-set Distance = 20 µm; Number of Sets = 3**
Meaning:
- Stripes repeat every 20 µm  
- Ensures uniform distribution of power  
- Prevents IR drop hotspots  

For small blocks, 2–3 stripe sets are typical.

If too few stripes:
- High IR drop  
- Cells far from stripes experience droop  

If too many:
- Routing congestion  
- Wasted power metal  

---

# 5.2.3 Special Routing (SRoute)

After adding rings and stripes, **SRoute** was performed to connect:
- Standard cell rails  
- Stripes  
- Rings  
- Block pins  

<img width="774" height="804" alt="Screenshot 2025-11-19 122328" src="https://github.com/user-attachments/assets/74414b6a-efbb-4057-9d94-bff8ba8943e6" />


---

### Why These SRoute Settings Were Used

#### 1. **Top Layer = Metal9, Bottom Layer = Metal1**
Allows SRoute to use the entire metal stack:
- Metal1 connects to std. cell rails (VDD/VSS rails)  
- Higher layers used for via stacks and connectivity  

#### 2. **Follow Pins = Enabled**
Ensures:
- Power pins inside standard cell rows are automatically connected to stripes/rings  
- No floating power pins  
- Clean LVS

#### 3. **Block Pins / Pad Pins = Enabled**
Ensures even macro pins (if present) get clean power connections.

#### 4. **Jogging + Layer Change Allowed**
Allows:
- Turning corners  
- Routing around obstacles  
- Choosing the best metal layer for a clean connection  

---

### Design after Power Planning

<img width="1900" height="951" alt="Screenshot 2025-11-19 124828" src="https://github.com/user-attachments/assets/c37261b1-00a9-4e6c-8cfb-e168aa18e047" />


---

## 5.3 Placement (Standard Cells + Physical Cells)

After completing floorplanning and power planning, the next step is **placement**, where Innovus positions all standard cells and physical-only cells inside the core area. Placement influences congestion, timing, and overall design quality.

Placement is performed in three stages:

1. **Place standard cells**  
2. **Insert physical-only cells (endcaps, tapcells, etc.)**  
3. **Insert filler cells**  

---

# 5.3.1 Standard Cell Placement

During standard cell placement, Innovus arranges all logic cells inside the standard cell rows defined during floorplanning.

### What Innovus does during placement:

- Places cells based on net connectivity and timing requirements  
- Reduces wirelength and congestion  
- Balances placement density according to utilization  
- Legalizes cell positions to align with placement rows  
- Ensures no overlapping cells  

### Why placement is essential:

- Good placement → easier routing → fewer DRC violations  
- Reduces timing delays by minimizing net lengths  
- Ensures even distribution of logic to avoid hotspots  

After placement, the core usually reaches **~60–70% density**, matching the core utilization target.

---

# 5.3.2 Physical-Only Cell Insertion

Certain cells do not perform logic but are essential for physical design. These are inserted after standard cell placement.

### Physical-only cell types:

| Cell Type | Purpose |
|-----------|----------|
| **Endcap Cells** | Placed at row boundaries to protect well regions and diffusion edges |
| **Tap Cells** | Connect wells to VDD/VSS to prevent latch-up |
| **End-of-Row Cells** | Close placement rows cleanly |
| **Well-Tie Cells** | Ensure proper connection to substrate/well |
| **Decap Cells** (optional) | Provide local charge storage to reduce IR drop |

### Why they are required:

- Prevents design rule violations (N-well, P-well spacing)  
- Maintains well/substrate bias  
- Ensures clean boundaries for rows  
- Supports a reliable power grid and reduces latch-up risk  

Physical-only cells do **not** appear in RTL or synthesis—they are added only during physical implementation.

---

# 5.3.3 Filler Cell Insertion

After all standard and physical-only cells are placed, whitespace remains between placed cells. Innovus fills these gaps with **filler cells**.

### Purpose of Fillers:

- Connect power rails (VDD/VSS) across gaps  
- Ensure continuity of Nwell/Pwell layers  
- Prevent DRC violations caused by breaks in diffusion  
- Maintain uniform density across the design  

Without fillers, routing and DRC will fail.

### Typical filler naming:
- `FILL1`
- `FILL2`
- `FILL4`
- `FILL8`

Innovus automatically chooses appropriate fillers depending on gap size.

---

# Design after placement

<img width="1831" height="955" alt="Screenshot 2025-11-19 124850" src="https://github.com/user-attachments/assets/d6560f89-5d4f-4a0b-9d48-f329d4a91b3d" />


---

## 5.4 Clock Tree Synthesis (CTS)

Clock Tree Synthesis (CTS) is one of the most important stages in physical design.  
Its goal is to distribute the clock signal from the clock source (port/pad) to all sequential elements (flip-flops) **with minimal skew and controlled latency**.

For this 4×4 pipelined multiplier, CTS was performed in **Cadence Innovus** after placement and physical-only cell insertion.

---

# What CTS Does

During CTS, Innovus automatically performs the following:

### 1. Identifies all clock sinks
All flip-flops inside:
- Stage 1 registers (`pp0`, `pp1`, `pp2`, `pp3`)
- Stage 2 registers (`s1_a`, `s1_b`)
- Stage 3 output register (`P`)

### 2. Inserts clock buffers/inverters
These buffers:
- Reduce clock skew  
- Balance the path delays  
- Improve drive strength  
- Maintain good transition times  

### 3. Builds a balanced clock tree
Innovus chooses a topology (typically a **balanced tree**) suitable for the design size.

### 4. Controls clock skew and latency
- **Clock skew** = difference in clock arrival time between two flops  
- **Latency** = time from clock source to sink  

CTS ensures both are within limits defined by the SDC.

### 5. Uses higher metal layers for clock routing
Clock routes are typically placed on higher metal layers to:
- Reduce resistance  
- Reduce coupling noise  
- Avoid signal routing congestion  

---

# Typical CTS Behavior for a Small Block

Since this multiplier is a small digital block:
- Only a **few** clock buffers are inserted  
- Tree depth is **1–2 levels**  
- Clock skew is generally **very small** (in tens of picoseconds)  
- Clock latency is moderate and uniform across pipeline stages  

This is expected for a design with a limited number of flip-flops and a compact floorplan.

---

# Why CTS Is Necessary

CTS ensures:
- All registers capture data at the correct edge of the clock  
- Setup timing is met (no path too slow)  
- Hold timing is met (no path too fast)  
- The pipeline stages stay synchronized  
- The design can run reliably at the target frequency (200 MHz)

Without CTS:
- The clock would arrive unevenly at different flops  
- Setup and hold violations would occur  
- Timing closure would fail  
- Silicon failure risk is extremely high  

---

# Post-CTS Optimization

After building the clock tree, Innovus performs additional optimizations:
- Fixing transition/slew violations  
- Hold time repair (buffer insertion)  
- Cell resizing  
- Fanout balancing  

This step refines the design before routing and ensures clean timing behavior post-CTS.

---

# Generated CTS 

 <img width="1920" height="1080" alt="Screenshot 2025-11-19 125330" src="https://github.com/user-attachments/assets/21e7e681-f492-4eed-bf16-f80a156d1266" />


---

## 5.5 Routing (NanoRoute)

Routing is the stage where all logical connections (nets) are physically realized using metal layers. After CTS and post-CTS optimization, Cadence Innovus performs global routing and detailed routing using its routing engine **NanoRoute**.

Routing must ensure:
- All nets are fully connected  
- No DRC (Design Rule Check) violations  
- Minimal crosstalk and congestion  
- Timing closure is maintained  

---

# What Routing Does

The routing process occurs in two major steps:

---

## 1. Global Routing

Global routing creates an approximate routing plan without drawing exact wires.  
It determines:

- Which metal layers to use  
- Path guides for each net  
- Congestion hotspots  
- Channel availability  
- Estimated delays  

Global routing **does not** draw the final wires but prepares the routing map for detailed routing.

Benefits:
- Avoids congestion early  
- Ensures each net has a valid route  
- Optimizes layer assignment before actual routing  

---

## 2. Detailed Routing (NanoRoute)

Detailed routing uses the guides from global routing and creates actual metal segments and vias.

NanoRoute:
- Lays down exact wires on specific metal layers  
- Inserts vias between layers  
- Ensures spacing, width, enclosure, density, and all DRC rules  
- Avoids power/clock tracks  
- Minimizes wirelength and delay  

After detailed routing:
- All nets are 100% connected  
- All DRC rules are checked and fixed  
- Timing is re-evaluated with final RC parasitics  

---

# Routing Strategy in This Design

Since the 4×4 pipelined multiplier is a small block with low cell density:
- Routing congestion is minimal  
- Only a few signal nets span across the block  
- Most routing happens on **Metal1/Metal2**  
- Higher layers are mainly used for power and clock networks  
- No macro blockages or long interconnects exist  

NanoRoute can easily route such a design cleanly, typically yielding:
- Zero or very few DRC violations  
- Short wirelength  
- Low crosstalk risk  
- Good post-route timing  

---

# Key Responsibilities of Router (NanoRoute)

### 1. DRC Compliance
Detailed routing ensures:
- Minimum spacing  
- Minimum width  
- Via enclosure  
- Metal density rules  
- Antenna rules (if enabled)  

A DRC-clean routed design is required before tapeout.

### 2. Via Insertion
Correct via stacks inserted when jumping layers.

### 3. Shielding / Wire Spacing (if required)
Not critical for such a small design but important in large, timing-sensitive blocks.

### 4. Timing Preservation
Routing attempts to:
- Minimize RC delay  
- Choose optimal routing layers  
- Avoid unnecessary detours  

Post-route timing improves compared to estimated timing before routing.

---

# Post-Route Optimization

After routing, Innovus may perform:
- Hold fixing (by inserting buffers or detouring wires)  
- Setup improvement (cell sizing, buffer insertion)  
- Slew/transition fixes  
- Crosstalk avoidance  

This produces a clean, timing-closed design after routing.

---

# Routing Completion

Once routing is completed:
- All connections are finalized  
- DRC checks are performed  
- Timing is updated with accurate RC extraction  
- The design is now ready for final extraction and signoff steps  

---

# Design after Routing

<img width="1916" height="1018" alt="Screenshot 2025-11-19 132104" src="https://github.com/user-attachments/assets/3eddd05c-6977-41f8-9d63-fe5e92fe3ff3" />


---

## 5.6 Timing Analysis and ECO (Engineering Change Order)

After routing is completed, Innovus performs **post-route timing analysis** using accurate RC parasitics.  
This is a critical stage where setup/hold violations may appear due to real wire delays, via stacks, and final routing detours.

To fix these violations, Innovus performs **ECO (Engineering Change Order)** operations.

Timing closure + ECO ensures the final design is functionally correct, meets the target frequency, and can be signed off safely.

---

# 5.6.1 Types of Timing Checks

## Setup Timing Check
Setup time ensures data arrives **before** the next active clock edge.

Violations occur when:
- Path delay is too long  
- Clock latency is too high  
- Slow cells or long wires increase delay  

Fixes include:
- Upsizing cells (stronger drive)  
- Buffer insertion  
- Re-routing / using higher metal layers  

---

## Hold Timing Check
Hold ensures data does **not change immediately after** the clock edge.

Violations occur when:
- Path delay is too short  
- Clock skew makes data arrive earlier than expected  

Fixes include:
- Inserting delay buffers  
- Using smaller/weaker cells  
- Wire detouring to increase delay  

---

# 5.6.2 Pre-CTS ECO

Performed **before CTS**, after placement.

Purpose:
- Fix placement-related issues  
- Remove legal violations  
- Balance path lengths  
- Prepare a better starting point for CTS  

Typical operations:
- Cell resizing  
- Rebuffering  
- Gate cloning  
- Cell spreading (to reduce congestion)  

---

# 5.6.3 Post-CTS ECO

Performed immediately after CTS finishes.

Why?  
After inserting clock buffers, skew changes, causing:
- New hold violations  
- Small setup violations  
- Transition/slew violations  

Operations performed:
- Inserting small delay buffers for hold  
- Buffer resizing for better transitions  
- Fixing nets with poor RC conditions  

---

# 5.6.4 Post-Route Timing Analysis

Once routing is completed and final wires are drawn, Innovus performs **post-route timing analysis** with accurate parasitics.

At this stage:
- Actual RC values (from metal resistance + coupling capacitance) are used  
- Timing numbers closely match real silicon behavior  

This analysis is used for:
- Timing signoff  
- SDF generation  
- Final ECO fixes  

---

# 5.6.5 Post-Route ECO

Final round of ECO to close timing with accurate delays.

Fixes include:
- Adding hold buffers  
- Increasing drive strength  
- Replacing slow cells  
- Re-routing critical paths  
- Adding shielding or spacing (for crosstalk-sensitive nets)  

The goal is **zero setup and hold violations** at all corners.

---

# 5.6.6 ECO Philosophy Summary

| ECO Stage | When It Happens | Purpose |
|----------|------------------|---------|
| Pre-CTS ECO | After placement | Clean placement, reduce congestion, prepare for CTS |
| Post-CTS ECO | After clock tree | Fix skew-related hold violations, improve timing |
| Post-Route ECO | After routing | Final timing closure with accurate RC delays |

---

# 5.6.7 When Is Timing Closure Complete?

Timing closure is considered successful when:

- **WNS (Worst Negative Slack) ≥ 0**  
- **TNS (Total Negative Slack) = 0**  
- **No setup or hold violations remain**  
- **All constraints from SDC are satisfied**  
- **All corners (slow/fast) meet requirements**  

Only then can the design proceed to extraction, SDF generation, and signoff.

---

# 5.6.8 Setup and Hold Timing Report

<img width="1083" height="693" alt="Screenshot 2025-11-19 125659" src="https://github.com/user-attachments/assets/20650840-61d9-45a7-864f-fab8a2fcdee9" />

---

## 5.7 RC Extraction, Corner Analysis, and SDF Generation

After timing closure and final ECO, the next step is **RC Extraction**.  
This stage extracts the actual parasitic resistance (R) and capacitance (C) from the routed layout.  
These parasitics are essential for accurate timing analysis and for generating the final SDF file used in gate-level simulation.

---

# 5.7.1 What RC Extraction Does

During routing, nets are connected using metal layers and vias. The resistance and capacitance of these wires significantly affect signal delays.

RC Extraction performs the following:

- Computes metal **resistance** based on wire length, metal width, and layer properties  
- Extracts **coupling capacitance** between adjacent wires  
- Extracts **ground capacitance** to substrate  
- Builds a complete **parasitic netlist (SPEF)**  
- Updates timing to reflect real physical delays  
- Gives realistic post-route timing numbers  

Without RC extraction, all timing would still be based on estimates, not real silicon behavior.

---

# 5.7.2 Corners Used for Post-Route Timing

Once extraction is completed, Innovus performs timing checks across **multiple corners**:

### • Worst Case (Slow-Max Corner)
- Slow process  
- Maximum temperature  
- Minimum voltage  
- Maximum RC parasitics  

Used to check **setup timing** (paths too slow).

### • Best Case (Fast-Min Corner)
- Fast process  
- Minimum temperature  
- Maximum voltage  
- Minimum RC parasitics  

Used to check **hold timing** (paths too fast).

### Why Corner Analysis Matters

Different manufacturing variations cause:
- Some chips to be **slower** (affect setup)  
- Some to be **faster** (affect hold)  

Checking both guarantees:
- No setup violations in slow conditions  
- No hold violations in fast conditions  

Failing either corner results in silicon failure.

---

# 5.7.3 SPEF Generation (Parasitic File)

The extracted parasitics are stored in a file called **SPEF** (Standard Parasitic Exchange Format).

SPEF includes:
- Wire resistance  
- Ground capacitance  
- Coupling capacitance  
- Net-to-net parasitics  

SPEF is fed into timing analysis for accurate delays.

---

# 5.7.4 SDF Generation (Standard Delay Format)

After SPEF-based timing is completed, Innovus generates the final **SDF** file.

### SDF contains:
- Cell delays  
- Net delays (from RC extraction)  
- Setup/hold values  
- Accurate path delays from real routed wires  

### SDF Files Generated
Two SDF files are typically generated:

| File Name | Corner | Usage |
|-----------|--------|--------|
| **func_slow_max.sdf** | Slow corner (max delay) | Used for setup checks & max delay gate-level simulation |
| **func_fast_min.sdf** | Fast corner (min delay) | Used for hold checks & min delay gate-level simulation |

These SDF files represent true post-route delays and are used during gate-level simulation to validate the design with timing.

---

# 5.7.5 Importance of SDF Back-Annotated Simulation

Running a gate-level simulation with SDF ensures:

- Timing is honored exactly as physical layout produced  
- No race conditions  
- No hold/setup violations  
- The pipeline behavior matches real hardware  
- Reset & clock synchronization issues are visible  
- The design behaves correctly with real parasitics  

This is the final functional timing validation before tape-out.

---

## 5.8 DRC, Connectivity Checks, Final Netlist, and Innovus Database Save

After routing, extraction, and timing closure, the final step of physical design is **design signoff** inside Innovus.  
This includes full DRC checks, connectivity validation, final netlist/SDF export, and saving the Innovus database for future use.

These steps ensure the layout is physically correct, electrically consistent, and fully ready for verification and tapeout.

---

# 5.8.1 DRC Verification (Design Rule Check)

DRC ensures the layout satisfies all manufacturing rules required by the technology node.

Innovus performs checks such as:

- Minimum metal spacing  
- Minimum metal width  
- Via enclosure rules  
- Via spacing  
- Wire density  
- Minimum area violations  
- Notches and jogs  
- End-of-line rules  

A **DRC-clean** design is mandatory for fabrication.

### Why DRC Is Needed
- Prevents metal shorts and opens  
- Ensures manufacturability  
- Avoids antenna effects  
- Prevents lithography printing errors  

Any DRC violation can result in silicon failure.

---

# 5.8.2 Connectivity Verification

Connectivity checks ensure:
- All power nets (VDD/VSS) are properly connected  
- No floating pins  
- No missing connections after routing  
- No disjointed or broken nets  
- All via stacks are valid  

This step verifies both logical and physical connectivity:
- Logical connectivity matches synthesized netlist  
- Physical wiring matches logical intent  

Connectivity issues often arise due to:
- Missing vias  
- Incorrect macro pin connections  
- Unintended shorts  

Innovus flags all such issues for correction.

---

# 5.8.3 Final Netlist Generation

After all ECOs and final routing, Innovus exports the **post-route netlist**.

This netlist includes:
- Inserted CTS buffers  
- Hold-fix buffers  
- Replaced or resized cells  
- Tie cells, filler cells, tapcells  
- All optimizations made during physical design  

### Why Post-Route Netlist Is Required
- Used for final timing signoff  
- Used in SDF back-annotated gate-level simulation  
- Required for LVS comparison against GDS  
- Represents the true, final hardware implementation  

---

# 5.8.4 SDF File Export

Innovus exports the final SDF files:
- **func_slow_max.sdf** (max delay)  
- **func_fast_min.sdf** (min delay)  

These SDFs include:
- Accurate post-route cell and interconnect delays  
- Setup and hold constraints  
- Min/Max path delays  
- Clock tree delays and insertion latencies  

These are used for gate-level simulations with timing.

---

# 5.8.5 Saving Innovus Database (.enc)

The final step is saving the Innovus design database:

- Saves all placement, routing, ECO changes, timing, and PDN information  
- Stored in `.enc` format  
- Allows reopening the design later without re-running full flow  
- Acts as design backup  


Developers use the `.enc` file for:
- Signoff checks  
- Future ECO changes  
- Regenerating GDS  
- Debugging timing or routing issues  

---

# 6. Conclusion

## Conclusion

This project implemented a complete **RTL-to-GDSII flow** for a 4×4 pipelined multiplier.  
Starting from Verilog RTL, the design was taken through:

- RTL design and functional simulation (NCLaunch)  
- Synthesis using Cadence Genus  
- Physical design using Cadence Innovus  
- Floorplanning, power planning, placement, and routing  
- Clock tree synthesis (CTS)  
- Timing closure with ECO optimization  
- Parasitic extraction and corner-based timing analysis  
- SDF generation for gate-level simulation  
- Final signoff checks (DRC + connectivity)  
- Saving the final Innovus database  

This flow demonstrates a **complete ASIC implementation**, showcasing all major steps required to turn an RTL description into a manufacturable layout.  
The pipelined multiplier achieves:

- **High throughput** (1 output per cycle after initial latency)  
- **Good timing performance** under realistic parasitics  
- **Clean routing and power distribution** for reliability  
- **Fully verified functionality** across all corners  

---







