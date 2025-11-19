# 1. Project Overview

The **4×4 Pipelined Multiplier (RTL → GDSII)** project demonstrates a complete end-to-end VLSI design flow, starting from RTL Verilog design and progressing all the way to signoff-level physical implementation using industry-standard tools such as:

- Cadence Genus (logic synthesis)
- Cadence Innovus (physical design, routing & signoff)
- NCLaunch / Xcelium (simulation & verification)

This project implements a **3-stage pipelined 4-bit × 4-bit multiplier**, optimized for high throughput. By pipelining the multiplier, new inputs are accepted every clock cycle while previous operations propagate through the stages. This significantly increases performance compared to a purely combinational multiplier.

---

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
| RTL Simulation | NCLaunch / Xcelium | Functional simulation |
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

## Pipeline Architecture Diagram

```
        ┌───────────────┐      ┌────────────────┐      ┌──────────────────┐
A[3:0]──►   Stage 1      ├─────►    Stage 2       ├─────►    Stage 3        ├──► P[7:0]
B[3:0]──► Partial Product│      │ Partial Sums    │      │ Final Addition   │
        │  Generation    │      │ Accumulation    │      │ & Output Reg     │
        └──────┬────────┘      └────────┬────────┘      └────────┬─────────┘
               │                        │                        │
        pp0, pp1, pp2, pp3        s1_a, s1_b                 Registered P
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

