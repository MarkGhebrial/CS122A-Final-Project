`include "src/communication.sv"
`timescale 1ns/1ps

module communication_tb;

logic clk = 0;

// Unit under test
communicator uut
(
    .clk(clk)
);

always begin 
    #1;
    clk =~ clk; // Toggle the clock
end

initial begin
    $dumpfile("build/communication.vcd"); // intermediate file for waveform generation
    $dumpvars(0, communication_tb);       // capture all signals under top_tb
end

initial begin
    for (int i = 0; i < 150000; i = i + 1) begin
        #2;
    end

    $finish;
end

endmodule
