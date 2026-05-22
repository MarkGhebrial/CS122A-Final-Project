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
    (8'b01000000 | COMMAND_INDEX) << (5*8) | \
    (COMMAND_ARGUMENT << 8) | \
    ((CRC << 1) | 1'b1)

`define SPI_BEGIN_TRANSFER(NUM_BYTES, DATA) \
    start_tx <= 1; \
    num_bytes <= NUM_BYTES; \
    tx_data <= DATA;

`define RESET_STATE_MACHINE() \
    state <= START_STATE; \
    status <= ERROR_RETRYING; \
    counter <= 0;

typedef enum logic[1:0] {
    // The module is going through the initialization routine for the first time
    INITIALIZING = 0,
    // An error was encountered and the module is retrying the initialization routine
    ERROR_RETRYING = 1,
    // The module is reading a block
    READING_BLOCK = 2,
    // The module is done reading the block and is currently doing nothing
    IDLE = 3,
} spi_module_status;

module sd_card(
    // Clock source
    input wire clk,

    // The address of the block to read from
    input wire[31:0] block_addr,
    
    // The status of the module
    output spi_module_status status = INITIALIZING,

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

    // // Waiting for CMD58 transmission
    // CMD58_SEND_STATE,
    // // Waiting for CMD58 reply
    // CMD58_RCV_STATE0,
    // CMD58_RCV_STATE1,

    // Waiting for CMD16 transmission
    CMD16_SEND_STATE,
    // Waiting for CMD16 reply
    CMD16_RCV_STATE,
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
    IDLE_STATE
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
                // Go to the next state
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
            if (tx_done) begin
                // Correct response. Go to next state
                if (rx_data) begin
                    // Go to the next state
                    state <= CMD8_SEND_STATE;
                    counter <= 0;
                    // Start transmitting CMD8
                    `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(8, 'h1AA, 7'b1000011));
                end
                // Wrong response. Read another byte
                else begin
                    if (counter < 16) begin
                        // Read another byte
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end
                    else begin
                        // Give up
                        `RESET_STATE_MACHINE();
                    end
                end
            end
        end

        CMD8_SEND_STATE: begin
            // Wait until CMD8 is done transmitting
            if (tx_done) begin
                state <= CMD8_RCV_STATE0,
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        // Receiving the first byte of the CMD8 response
        CMD8_RCV_STATE0: begin
            if (tx_done) begin
                // If the MSB of the response byte is 0, go to the next state
                if (!(rx_data & (1 << 7))) begin
                    // Go to the next state
                    state <= CMD8_RCV_STATE1;
                    counter <= 0;
                    // Begin reading the next 32 bits of the response
                    `SPI_BEGIN_TRANSFER(4, 'hFFFFFFFF);
                end
                // Otherwise, read another byte
                else begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE();
                    end
                end
            end
        end
        // Receiving the last 4 bytes of the CMD8 response
        CMD8_RCV_STATE1: begin
            // If we're done reading the rest of the CMD8 response...
            if (tx_done) begin
                /// ...verify that the response is correct...
                if (rx_data == 'h1AA) begin
                    // ... and go to the next state
                    `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(55, 0))
                    state <= CMD55_SEND_STATE;
                end
                else begin
                    `RESET_STATE_MACHINE();
                end
            end
        end

        CMD55_SEND_STATE: begin
            // Wait until the transfer finishes
            if (tx_done) begin
                state <= CMD55_RCV_STATE;
                `SPI_BEGIN_TRANSFER(1, 'hFF);
            end
        end
        CMD55_RCV_STATE: begin
            if (tx_done) begin
                if (!(rx_data & (1 << 7))) begin
                    // Go to the next state
                    state <= CMD41_SEND_STATE;
                    counter <= 0;
                    `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(41, 'h40000000));
                end
                else begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE();
                    end
                end
            end
        end
        CMD41_SEND_STATE: begin
            if (tx_done) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD41_RCV_STATE;
            end
        end
        CMD41_RCV_STATE: begin
            if (tx_done) begin
                // 1st case: we need to transfer another byte
                if (rx_data & (1 << 7)) begin
                    if (counter < 16) begin
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                        counter <= counter + 1;
                    end else begin
                        `RESET_STATE_MACHINE();
                    end
                end
                else begin
                    if (rx_data == 'h01) begin
                        // Send CMD55 again
                        `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(55, 0))
                        state <= CMD55_SEND_STATE;
                        counter <= 0;
                    end
                    else begin
                        // Go send CMD16
                        state <= CMD16_SEND_STATE;
                        counter <= 0;
                        `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(16, 'h200));
                    end
                end
            end
        end

        CMD16_SEND_STATE: begin
            // Wait for the transfer to finish
            if (tx_done) begin
                `SPI_BEGIN_TRANSFER(1, 'hFF);
                state <= CMD16_RCV_STATE;
            end
        end
        CMD16_RCV_STATE: begin
            if (tx_done) begin
                // If the MSB of the data is 1, read another byte
                if (rx_data & (1 << 7)) begin
                    if (counter < 16) begin
                        count <= count + 1;
                        `SPI_BEGIN_TRANSFER(1, 'hFF);
                    end else begin
                        `RESET_STATE_MACHINE();
                    end
                end
                else begin
                    state <= CMD17_SEND_STATE;
                    status <= READING_BLOCK;
                    counter <= 0;
                    `SPI_BEGIN_TRANSFER(4, `SPI_COMMAND(17, block_addr));
                end
            end
        end


        CMD17_SEND_STATE: begin

        end
        CMD17_RCV_STATE: begin

        end
        BLOCK_READ_STATE: begin

        end
        CHECKSUM_READ_STATE: begin

        end

        // Waiting for block_addr to change
        IDLE_STATE: begin

        end
    endcase
end


endmodule