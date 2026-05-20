`include "src/controller.sv"
`default_nettype none

/*
SD card SPI command format:
MSB |  "01", 6-bit command index
    |  MSB | 32-bit command argument
    |      | 
    |      |
    |  LSB v
LSB v  7-bit CRC checksum, "1"
*/
`define SPI_COMMAND(COMMAND_INDEX, COMMAND_ARGUMENT, CRC=0) \
    (2'b01000000 | COMMAND_INDEX) << (5*8) | \
    (COMMAND_ARGUMENT << 8) | \
    ((CRC << 1) | 1'b1)

`define SPI_BEGIN_TRANSFER(NUM_BYTES, DATA) \
    start_tx <= 1; \
    num_bytes <= NUM_BYTES; \
    tx_data <= DATA;

module sd_card(
    // Clock source
    input wire clk,

    // The address of the block to read from
    input wire[31:0] block_addr,
    
    // The status of the module
    output logic[1:0] status,

    output wire sck,
    output wire poci,
    output wire pico,
    output logic cs = 0,
);

// A register used by the state machine for counting the number of cycles spent in the current state
logic[7:0] counter = 0;

typedef enum {
    /** BEGIN CARD INITIALIZATION STATES **/
    // Start state
    START_STATE,
    // Sending "dummy cycles" with CS high
    DUMMY_CYCLE_STATE,

    // Waiting for CMD0 transmission
    CMD0_SEND_STATE,
    // Waiting for CMD0 reply
    CMD0_RCV_STATE,

    // Waiting for CMD8 transmission
    CMD8_SEND_STATE,
    // Waiting for CMD8 reply
    CMD8_RCV_STATE0,
    CMD8_RCV_STATE1,
    
    // Waiting for CMD55 transmission
    CMD55_SEND_STATE,
    // Waiting for CMD55 reply
    CMD55_RCV_STATE,
    // Waiting for CMD41 transmission
    CMD41_SEND_STATE,
    // Waiting for CMD41 reply
    CMD41_RCV_STATE,

    // Waiting for CMD58 transmission
    CMD58_SEND_STATE,
    // Waiting for CMD58 reply
    CMD58_RCV_STATE,

    // Waiting for CMD16 reply
    CMD16_STATE,
    /** END CARD INITIALIZATION STATES **/

    /** BEGIN BLOCK READ STATES **/
    // Waiting for CMD17 transmission
    CMD17_SEND_STATE,
    // Waiting for CMD17 reply
    CMD17_RCV_STATE,
    // Reading bytes from the block
    BLOCK_READ_STATE,
    // Reading checksum at end of block
    CHECKSUM_READ_STATE,
    /** END BLOCK READ STATES **/

    // Waiting for block_addr to change
    IDLE
} states;

states state;

logic start_tx = 0;
wire tx_done;
logic[2:0] num_bytes = 0;
logic[63:0] tx_data = 0;
logic[63:0] rx_data = 0;
spi_controller spi (
    .clk(clk),
    .start_tx(start_tx),
    .tx_done(tx_done),
    .num_bytes(num_bytes),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .sck(sck),
    .poci(poci),
    .pico(pico),
);

always @(posedge tx_done) begin
    start_tx <= 0;
end

always @(posedge clk) begin
    case (state)
        START_STATE: begin
            // Send four bytes of 0xFF with cs inactive
            cs <= 1;
            `SPI_BEGIN_TRANSFER(4, 64'hFFFFFFFF);
            // Unconditionally go to the next state
            state <= DUMMY_CYCLE_STATE;
        end
        DUMMY_CYCLE_STATE: begin
            // Wait until the SPI data transfer is over
            if (tx_done) begin
                state <= CMD0_SEND_STATE;
                cs <= 0;
                `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(0, 0, 7'b1001010));
            end
        end
        CMD0_SEND_STATE: begin
            // Wait until the SPI data transfer is over
            if (tx_done) begin
                state <= CMD0_RCV_STATE;
                // Transfer 0xFF so we can read the response from the card
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        CMD0_RCV_STATE: begin
            // If the transmission is done and the response bit is 0x01, go send CMF8
            if (tx_done && rx_data == 64'h01) begin
                `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(8, 'h1AA, 7'b1000011));
                state <= CMD8_SEND_STATE;
                counter <= 0;
            end
            // If the transmission is done but the response is not 
            else if (tx_done) begin
                if (counter < 16) begin 
                    // Read another byte
                    `SPI_BEGIN_TRANSFER(1, 'hFF);
                    counter <= counter + 1;
                end else begin
                    // We didn't get the expected reply, so start over.
                    state <= START_STATE;
                    counter <= 0;
                end
            end
        end

        CMD8_SEND_STATE: begin
            if (tx_done) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD8_RCV_STATE0,
            end
        end
        // Receiving the first byte of the CMD8 response
        CMD8_RCV_STATE0: begin
            if (tx_done && !(rx_data & (1 << 7))) begin
                // Go to the next state
                `SPI_BEGIN_TRANSFER(4, 'hFFFFFFFF);
                state <= CMD8_RCV_STATE1;
                counter <= 0;
            end
            else if (tx_done) begin
                if (counter < 16) begin
                    `SPI_BEGIN_TRANSFER(1, 'hFF);
                    counter <= counter + 1;
                end else begin
                    state <= START_STATE;
                    counter <= 0;
                end
            end
        end
        CMD8_RCV_STATE1: begin
            if (tx_done) begin
                if (rx_data == 'h1AA) begin
                    // Success, go to the next state
                    state <= 
                end
            end
        end
    endcase
end


endmodule