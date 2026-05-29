`include "src/top.sv"
`timescale 1ns/1ps
`default_nettype none

module top_tb;

initial begin
    $dumpfile("build/top.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb
end

logic clk = 1;


top uut
(
    .clk(clk)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

initial begin
    #15000;

    $finish;
end

endmodule
