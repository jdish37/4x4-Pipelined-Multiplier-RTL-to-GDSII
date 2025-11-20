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
    reg [5:0] s1_a; // Max: (15) + (15<<1) = 15+30 = 45 (needs 6 bits)
    reg [7:0] s1_b; // Max: (15<<2) + (15<<3) = 60+120 = 180 (needs 8 bits)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_a <= 6'd0;
            s1_b <= 8'd0;
        end else begin
            // Combinational logic for Stage 2 (reads from Stage 1 registers):
            // Add pp0 + (pp1 << 1)
            s1_a <= {2'b00, pp0} + {1'b0, pp1, 1'b0};
            
            // Add (pp2 << 2) + (pp3 << 3)
            s1_b <= {pp2, 2'b00} + {pp3, 3'b000};
        end
    end

    // --- STAGE 3 Register: Final Product ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P <= 8'd0;
        end else begin
            // Combinational logic for Stage 3 (reads from Stage 2 registers):
            // Add the two partial sums
            P <= s1_a + s1_b;
        end
    end

endmodule
