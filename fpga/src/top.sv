`include "src/sd_card.sv"
// `include "src/spi_controller.sv"

module top (
    input wire clk, 
    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs, // SD card chip select

    output wire pico_sck, // Pi Pico sck
    input wire pico_poci, // Pi pico data input
    output wire pico_pico, // Pi pico data output
);

spi_module_status status;

logic[31:0] block_addr = 0;
wire[511:0] block_data;

sd_card card_controller (
    .clk(clk),
    .block_addr(block_addr),
    .status(status),
    .sck(sd_sck),
    .poci(sd_poci),
    .pico(sd_pico),
    .cs(sd_cs),
);

logic pico_start_tx;
wire pico_tx_done;
logic[2:0] pico_num_bytes = 8;
logic[63:0] pico_tx_data;
wire[63:0] pico_tx_data;
spi_controller pico_controller (
    .clk(clk),
    .start_tx(pico_start_tx),
    .tx_done(pico_tx_done),
    .num_bytes(pico_num_bytes),
    .tx_data(pico_tx_data),
    .rx_data(pico_tx_data),
    .sck(pico_sck),
    .poci(pico_poci),
    .pico(pico_pico)
);
always @(posedge pico_tx_done) begin
    pico_start_tx <= 0;
end

always @(posedge clk) begin
    // When the sd_card module is done reading the block
    if (status == IDLE) begin
        // If we're not currently transmitting anything over to the pico...
        if (pico_tx_done) begin
            // ..transmit the upper 64 bits of the block
            pico_tx_data <= block_data[511:448];
            pico_num_bytes <= 8;
            pico_start_tx <= 1;

            // Then start reading the next block
            block_addr <= block_addr + 1;
        end
    end
    else if (status == INITIALIZING) begin
        // Transmit "INIT" to the pico over SPI
        if (pico_tx_done) begin
            pico_tx_data <= "INIT";
            pico_num_bytes <= 4;
            pico_start_tx <= 1;
        end
    end
    else if (status == ERROR_RETRYING) begin
        // Transmit "ERR" to the pico over SPI
        if (pico_tx_done) begin
            pico_tx_data <= "ERR";
            pico_num_bytes <= 3;
            pico_start_tx <= 1;
        end
    end
end

endmodule