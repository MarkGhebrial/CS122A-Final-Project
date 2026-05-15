`include "src/spi_controller.sv"

module sd_card(
    // Clock source
    input wire clk,

    // The address of the block to read from
    input wire[31:0] block_addr,
    
    // The status of the module
    output wire[1:0] status,

    output wire sck,
    output wire poci,
    output wire pico,
    output logic cs = 0,
);

// A register used by the state machine for counting the number of cycles spent in the current state
logic[7:0] counter = 0;

typedef enum logic[7:0] {
    /** BEGIN CARD INITIALIZATION STATES **/
    // Start state
    START_STATE,
    // Sending "dummy cycles" with CS high
    DUMMY_CYCLE_STATE,

    // Waiting for CMD0 transmission
    CMD0_SEND_STATE,
    // Waiting for CMD0 reply
    CMD0_RCV_STATE,

    // Waiting for CMD8 reply
    CMD8_STATE,
    
    // Waiting for CMD55 reply
    CMD55_STATE,
    // Waiting for CMD41 reply
    CMD41_STATE,

    // Waiting for CMD58 reply
    CMD58_STATE,
    // Waiting for CMD16 reply
    CMD16_STATE,
    /** END CARD INITIALIZATION STATES **/

    /** BEGIN BLOCK READ STATES **/


    // Waiting for block_addr to change
    IDLE
} state;

logic spi_go = 0;
logic[2:0] spi_num_bytes = 0;
logic[63:0] spi_tx_data = 0;
logic[63:0] spi_rx_data = 0;
spi_controller spi (
    .clk(clk),
    .go(spi_go),
    .num_bytes(spi_num_bytes),
    .sck(sck),
    .poci(poci),
    .pico(pico)
);

always @(posedge clk) begin
    // prev_state <= state;
    // if (prev_state == state) counter <= 0;
    // else counter <= counter + 1;

    case (state)
        START_STATE: begin
            // Send four bytes of 0xFF with cs inactive
            cs <= 1;
            spi_go <= 1;
            spi_num_bytes <= 4;
            spi_tx_data <= 64'hFFFFFFFF;
            // Unconditionally go to the next state
            state <= DUMMY_CYCLE_STATE;
        end
        DUMMY_CYCLE_STATE: begin
            // Wait until the SPI data transfer is over
            if (!go) begin
                state <= CMD0_STATE;
                cs <= 0;
                spi_go <= 1;
                spi_num_bytes <= 4;
                spi_tx_data <= 0; // TODO: CMD0 value
            end
        end
        CMD0_SEND_STATE: begin
            // Go to the next state once this one is done
            if (!go) begin
                state <= CMD0_RCV_STATE;
                spi_go <= 1;
                spi_num_bytes <= 1;
                spi_tx_data <= 64'hFF;
                counter <= 0;
            end
        end
        CMD0_RCV_STATE: begin
            // If the transmission is done and the response bit is 0x01
            if (!go && spi_rx_data == 64'h01) begin
                // TODO: Go to the next state
            end
            else if (!go) begin
                if (counter < 8) begin 
                    // Read another byte
                    go <= 1;
                    counter <= counter + 1;
                end else begin
                    // We didn't get the expected reply, so start over.
                    state <= START_STATE;
                end
            end

        end
    endcase
end


endmodule