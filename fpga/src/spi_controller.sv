module spi_controller (
    input wire clk,

    // Toggle this to begin data transfer.
    input wire start_tx,
    output wire transmitting,

    // The number of bytes to transfer. Maximum is 8.
    input wire[3:0] num_bytes,
    // The data to send in the transfer (MSB first)
    input wire[63:0] tx_data,
    // The data received in the transfer (MSB first)
    output logic[63:0] rx_data = 0,
    
    // Clock signal
    output wire sck,
    // Peripheral out, controller in
    input logic poci,
    // Peripheral in, controller out
    output logic pico = 0
);

// Counts the number of bits transmitted
logic[6:0] counter = 0;

logic sck_en = 0;
logic prev_start_tx = 0;

always @(posedge clk) begin
    prev_start_tx <= start_tx;

    if (transmitting) begin
        if (counter < num_bytes * 8) begin
            sck_en <= 1;
            counter <= counter + 1;
            // Write to pico on falling edges of the clock pin
            pico <= (tx_data >> (num_bytes*8 - counter - 1)) & 1'b1;
        end else begin
            counter <= 0;
            sck_en <= 0;
        end
    end
end

// Read poci on rising edges of the clock pin
always @(posedge sck) begin
    if (sck_en) begin
        // Receive a bit
        rx_data <= { rx_data[62:0], poci } & (~64'b0 >> 8*(8-num_bytes));
        //                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mask off the most significant bits based on the number of bytes we're receiving
    end
end

assign transmitting = start_tx != prev_start_tx || sck_en;

assign sck = sck_en && ~clk;

endmodule