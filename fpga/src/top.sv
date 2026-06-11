`default_nettype none

`include "src/main.sv"
`include "src/eight_mhz.v"

module top (
    input wire clk,
    
    output wire sd_sck,
    input wire sd_poci,
    output wire sd_pico,
    output wire sd_cs,

    input wire pico_clk,
    output wire pico_data,

    output wire[5:0] logic_analyzer_pins
);

wire slow_clk;
wire locked;
pll p (
    .clkin(clk),
    .clkout0(slow_clk),
    .locked(locked)
);

// All functionality is separated into this module because we can't simulate the pll
wire sd_sck;

main m (
    .clk(slow_clk),
    .sd_sck(sd_sck),
    .sd_poci(sd_poci),
    .sd_pico(sd_pico),
    .sd_cs(sd_cs),
    .pico_clk(pico_clk),
    .pico_data(pico_data)
);

assign logic_analyzer_pins = {
    slow_clk,
    pico_data,

    sd_cs,
    sd_pico, // MOSI
    sd_poci, // MISO
    sd_sck
};

endmodule