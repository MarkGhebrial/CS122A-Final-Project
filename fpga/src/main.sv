`include "src/sd_card.sv"
`include "src/communication.sv"
`include "src/peripheral.sv"

module main (
    input wire clk,

    // Pins for SPI communication with the SD card
    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs, // SD card chip select

    // Pins for SPI communication with the Pi Pico
    input wire pico_clk,
    output wire pico_data
);

wire internal_clk;
assign internal_clk = clk & en;

wire en;
wire pico_sck;
wire pico_pico;

wire sd_start_tx;
wire sd_transmitting;
wire[3:0] sd_num_bytes;
wire[63:0] sd_tx_data;
wire[63:0] sd_rx_data;
spi_controller sd_card_spi (
    .clk(internal_clk),
    .start_tx(sd_start_tx),
    .transmitting(sd_transmitting),
    .num_bytes(sd_num_bytes),
    .tx_data(sd_tx_data),
    .rx_data(sd_rx_data),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico)
);

wire[31:0] block_addr;
wire[511:0][7:0] block_data;
sd_module_status status;
sd_module_state state;
sd_card sd_card_controller (
    .clk(internal_clk),
    .block_addr(block_addr),
    .block_data(block_data),
    .status(status),
    .state(state),
    .start_tx(sd_start_tx),
    .spi_transmitting(sd_transmitting),
    .num_bytes(sd_num_bytes),
    .tx_data(sd_tx_data),
    .rx_data(sd_rx_data),
    .cs(sd_cs)
);

communicator c (
    .clk(internal_clk),
    .block_addr(block_addr),
    .block_data(block_data),
    .status(status),
    .sck(pico_sck),
    .pico(pico_pico)
);

peripheral p (
    .sck(pico_sck),
    .communicator(pico_pico),
    .en(en),
    .pico_clk(pico_clk),
    .pico_data(pico_data)
);

endmodule