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
        // (Easy to read on waveform)
        // --------------------------
        
        // Cycle 1
        @(posedge clk);
        A = 4'd3; B = 4'd2;   // Expect 6 → after 3 cycles

        // Cycle 2
        @(posedge clk);
        A = 4'd7; B = 4'd4;   // Expect 28 → after next 3 cycles

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

