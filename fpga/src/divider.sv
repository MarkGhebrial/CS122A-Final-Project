module divider
(
  input logic pclk,        
  output logic clkout     // DIN
);

logic [3:0] count = 0;

always @ (posedge pclk)begin
  if (count == 9)begin
    count <= 0;
  end
  else begin
    count <= count + 1;
  end

  clkout <= count > 4;
end

endmodule