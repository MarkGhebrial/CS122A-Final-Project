`default_nettype none

`include "src/main.sv"
`include "src/eight_mhz.v"

module top (
    input wire clk,
    input wire en,
    
    output wire sd_sck,
    input wire sd_poci,
    output wire sd_pico,
    output wire sd_cs,

    output wire pico_sck,
    output wire pico_pico,

    output wire[7:0] logic_analyzer_pins
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
    .en(1),
    .sd_sck(sd_sck),
    .sd_poci(sd_poci),
    .sd_pico(sd_pico),
    .sd_cs(sd_cs),
    .pico_sck(pico_sck),
    .pico_pico(pico_pico)
);

assign logic_analyzer_pins = {
    en,
    slow_clk,
    pico_pico,
    pico_sck,

    sd_cs,
    sd_pico, // MOSI
    sd_poci, // MISO
    sd_sck
};

endmodule