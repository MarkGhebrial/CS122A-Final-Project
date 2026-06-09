`include "src/sd_card.sv"
`include "src/eight_mhz.v"

module main (
    input wire clk, 

    // Pins for SPI communication with the SD card
    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs // SD card chip select

    // Pins for SPI communication with the Pi Pico
    // output wire pico_sck
);

wire start_tx;
wire transmitting;
wire[3:0] num_bytes;
wire[63:0] tx_data;
wire[63:0] rx_data;
spi_controller pico_controller (
    .clk(clk),
    .start_tx(start_tx),
    .transmitting(transmitting),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico)
);

logic[31:0] block_addr = 0;
wire[511:0] block_data;
sd_module_status status;
sd_module_state state;
sd_card sd (
    .clk(clk),
    .block_addr(block_addr),
    .block_data(block_data),
    .status(status),
    .state(state),
    .start_tx(start_tx),
    .spi_transmitting(transmitting),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .cs(sd_cs)
);

always @(posedge clk) begin
    if (status == IDLE) begin
        block_addr <= block_addr + 1;
    end
end

endmodule