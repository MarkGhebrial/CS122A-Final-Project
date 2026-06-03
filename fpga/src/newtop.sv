`include "src/sd_card.sv"
`include "src/eight_mhz.v"

module newtop (
    input wire clk, 

    output wire sd_sck,
    input wire sd_poci, // SD card data input
    output wire sd_pico, // SD card data output
    output wire sd_cs, // SD card chip select
    
    output wire[7:0] logic_analyzer_pins
);

wire slow_clk;
wire locked;
pll p (
    .clkin(clk),
    .clkout0(slow_clk),
    .locked(locked)
);

wire start_tx;
wire transmitting;
wire[3:0] num_bytes;
wire[63:0] tx_data;
wire[63:0] rx_data;
spi_controller pico_controller (
    .clk(slow_clk),
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
    .clk(slow_clk),
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

logic[4:0] max_state = 0;

assign logic_analyzer_pins = {
    4'b0,
    sd_poci,
    sd_pico,
    sd_sck
    // status == READING_BLOCK
    // max_state == 6 //clk
};

always @(posedge clk) begin
    if (state > max_state) begin
        max_state <= state;
    end

    if (status == IDLE) begin
        if (block_addr == 0) begin
            block_addr <= 1;
        end else begin
            block_addr <= 0;
        end
        // block_addr <= block_addr + 1;
    end
end

endmodule