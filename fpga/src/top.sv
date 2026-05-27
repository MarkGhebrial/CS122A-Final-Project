`include "src/dac.sv"
`include "src/divider.sv"
`include "src/clk.v"
module top (
    /** Input Ports */
    input logic CLK,

    /** Output Ports */
    output logic DATAOUT,
    output logic DAC_CLK,
    output logic DAC_LRC
);

/** Logic */
logic clk512;
logic clkdiv;

pll clk5120(
    .clkin(CLK),
    .clkout0(clk512)
);

divider divider(
    .pclk(clk512),
    .clkout(clkdiv)
);

dac dac1 (
    .pclk(clkdiv),
    .dataOut(DATAOUT),
    .lrOut(DAC_LRC)
);

assign DAC_CLK = clkdiv;

endmodule