`include "src/sd_card.sv"
`include "src/dac.sv"
`include "src/divider.sv"
`include "src/clk.v"

module top (
    input wire clk, 
    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs, // SD card chip select

    // output wire pico_sck, // Pi Pico sck
    // input wire pico_poci, // Pi pico data input
    // output wire pico_pico, // Pi pico data output

    output spi_module_status status,

    output logic DATAOUT,
    output logic DAC_CLK,
    output logic DAC_LRC
);


logic[31:0] block_addr = 0;
wire[511:0] block_data;
sd_card card_controller (
    .clk(clk),
    .block_addr(block_addr),
    .status(status),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico),
    .cs(sd_cs)
);

/** Logic */
logic clk512;
logic clkdiv;

pll clk5120(
    .clkin(clk),
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