`include "src/dac.sv"
`include "src/divider.sv"
`timescale 1ns/1ps         // Set tick to 1ns. Set sim resolution to 1ps.

/**
 * Note:
 *  The TB below is only an example of a testbench written in SV.
 *  Adapt this for your lab assignments as you see fit.
 *  An example clk signal has been added to show what a signal decl and usage looks like.
 *     You are welcome to delete the clk signal if it's not needed.
 *     For instance, purely combinational circuits do not need clks.
 *     So for labs without sequential elements, you can remove them.
 */

module top_tb;

/** declare tb signals below */
logic clk_tb;
logic divclk_tb;
logic dataout_tb;
logic lrout_tb;

/** declare module(s) below */
divider divide(
    .pclk(clk_tb),
    .clkout(divclk_tb)
);

dac dut                    // declare an inst of top called "dut" (device under test)
(
    .pclk(divclk_tb),
    .dataOut(dataout_tb),
    .lrOut(lrout_tb)
);

localparam CLK_PERIOD = 4;
always #(CLK_PERIOD/2) clk_tb=~clk_tb;          // toggle clk_tb every #(CLK_PERIOD/2) ticks

initial begin
    $dumpfile("build/top.vcd"); // intermediate file for waveform generation
    $dumpvars(0, top_tb);       // capture all signals under top_tb
end

initial begin
    /** testbench logic goes below */
    clk_tb<=1'b1;       // sets clk_tb to 1
    #(CLK_PERIOD*3);    // waits for CLK_PERIOD * 3 ticks

    #(CLK_PERIOD*1000000);
    $finish;            // end simulation, otherwise it runs indefinitely
end

endmodule
