`include "src/sd_card.sv"
`timescale 1ns/1ps

module top_tb;

logic clk = 0;
logic[31:0] block_addr = 0;

wire[1:0] status;
wire sck;
wire poci;
wire pico;
wire cs;

// Unit under test
sd_card uut
(
    .clk(clk),
    .block_addr(block_addr),
    .status(status),
    .sck(sck),
    .poci(poci),
    .pico(pico),
    .cs(cs)
);

always begin 
    #1;
    clk =~ clk;
end

initial begin
    $dumpfile("build/sd_card.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb

    #(2 * 5000); // Wait 5000 clock cycles
    $finish; // End the simulation
end

initial begin
    for (int i = 0; i < 150000; i = i + 1) begin
        #2;
    end

    $finish;
end

endmodule
