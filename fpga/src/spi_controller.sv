module spi_controller (
    input wire clk,

    // Set this high to begin data transfer.
    input wire start_tx,
    output wire tx_done,

    // The number of bytes to transfer
    input wire[2:0] num_bytes,
    // The data to send in the transfer (MSB first)
    input wire[63:0] tx_data,
    // The data received in the transfer (MSB first)
    output logic[63:0] rx_data,
    
    // Clock signal
    output wire sck,
    // Peripheral out, controller in
    input logic poci,
    // Peripheral in, controller out
    output logic pico
);

// Counts the number of bits transmitted
logic[6:0] counter = 0;

logic transmitting = 0;
logic sck_en = 0;
always @(posedge start_tx) begin 
    transmitting <= 1;
end

always @(posedge clk) begin
    if (transmitting) begin
        if (counter < (num_bytes * 8) - 0) begin
            sck_en <= 1;
            counter <= counter + 1;
            // Transmit a bit
            pico <= (tx_data >> (num_bytes*8 - counter - 1)) & 1'b1;
            // Receive a bit
            rx_data <= { rx_data[62:0], poci } & (~64'b0 >> 8*(8-num_bytes));
            //                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Mask off the most significant bits based on the number of bytes we're receiving
        end else begin
            counter <= 0;
            // Indicate that the transmission has finished
            transmitting <= 0;
            sck_en <= 0;
        end
    end
end

assign tx_done = !transmitting;
assign sck = sck_en && ~clk;

endmodule