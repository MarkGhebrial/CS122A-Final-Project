`include "src/peripheral.sv"
`timescale 1ns/1ps

module peripheral_tb;

logic clk = 0;
logic sck = 0;
logic en;
logic pico_clk = 0;
logic pico_data;

// Unit under test
peripheral uut
(
    .clk(clk),
    .sck(sck),
    .en(en),
    .pico_clk(pico_clk),
    .pico_data(pico_data)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

initial begin
    $dumpfile("build/peripheral.vcd"); // intermediate file for waveform generation
    $dumpvars(0, peripheral_tb);       // capture all signals under top_tb
end

initial begin
    #2000

    $finish;
end

endmodule
