`include "src/spi_controller.sv"
`timescale 1ns/1ps
`default_nettype none

module top_tb;

initial begin
    $dumpfile("build/spi_controller.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb
end

logic clk = 1;

logic start_tx = 0;
wire tx_done;
logic[2:0] num_bytes = 0;
logic[63:0] tx_data = 0;
wire[63:0] rx_data;
wire sck;
logic poci = 0;
wire pico;
spi_controller uut
(
    .clk(clk),
    .start_tx(start_tx),
    .tx_done(tx_done),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .sck(sck),
    .poci(poci),
    .pico(pico)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

initial begin
    #2;
    // Read one byte
    num_bytes = 2;
    tx_data = 64'hBEEF;
    start_tx = 1;
    #2;
    start_tx = 0;
    #2;
    while(!tx_done) begin 
        poci = ~poci;
        #2;
    end

    $finish;
end

endmodule
