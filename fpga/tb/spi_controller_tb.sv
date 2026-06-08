`include "src/spi_controller.sv"
`timescale 1ns/1ps
`default_nettype none

module top_tb;

initial begin
    $dumpfile("build/spi_controller.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb
end

logic clk = 1;

logic start_tx = 1;
wire transmitting;
logic[3:0] num_bytes = 0;
logic[63:0] tx_data = 0;
wire[63:0] rx_data;
wire sck;
wire poci;
wire pico;
spi_controller uut
(
    .clk(clk),
    .start_tx(start_tx),
    .transmitting(transmitting),
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

logic[63:0] peripheral_data = 'h01;
int counter = 7;
always @(negedge sck) begin
    counter = counter - 1;
end
assign poci = peripheral_data[counter];

initial begin
    #2;
    // Read one byte
    num_bytes = 1;
    tx_data = 64'hFF;
    start_tx = ~start_tx;

    while(transmitting) begin
        #2;
    end
    #4;

    $finish;
end

endmodule
