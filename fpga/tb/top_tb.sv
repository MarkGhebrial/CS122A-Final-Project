`include "src/top.sv"
`timescale 1ns/1ps

module top_tb;

logic clk = 0;
logic sck = 0;
logic spi_in = 0;

wire lcd_clk;
wire lcd_den;
wire[4:0] lcd_r;
wire[5:0] lcd_g;
wire[4:0] lcd_b;

// Unit under test
top uut
(
    .clk(clk)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

initial begin
    $dumpfile("build/top.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb
end

initial begin
    for (int i = 0; i < 150000; i = i + 1) begin
        #2;
    end

    $finish;
end

endmodule
