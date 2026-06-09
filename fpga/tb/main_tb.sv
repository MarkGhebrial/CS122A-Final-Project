`include "src/main.sv"
`timescale 1ns/1ps

module main_tb;

logic clk = 0;

// Unit under test
main uut
(
    .clk(clk)
);

always begin 
    #1;
    clk =~ clk;
end

initial begin
    $dumpfile("build/main.vcd");
    $dumpvars(0, main_tb);
end

initial begin
    for (int i = 0; i < 150000; i = i + 1) begin
        #2;
    end

    $finish;
end

endmodule
