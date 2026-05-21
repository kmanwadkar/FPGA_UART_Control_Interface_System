`timescale 1ns / 1ps

module uart_transmitter_tb;

reg clk;
reg send_data;
reg baud_pulse;
reg[7:0] data_input;

wire baud_reset;
wire tx_out;

uart_transmitter dut (
    .clk(clk),
    .send_data(send_data),
    .baud_pulse(baud_pulse),
    .data_input(data_input),
    .baud_reset(baud_reset),
    .tx_out(tx_out)
);

always 
#5 clk = ~clk;

//generates faster baud pulse
reg[2:0] counter = 0;

always @(posedge clk) begin
    if (baud_reset) begin          
        counter    <= 0;
        baud_pulse <= 0;
    end
    else if (counter == 6'd6) begin
        counter <= 0;
        baud_pulse <= 1;
      end
    else begin
        counter <= counter + 6'd1;
        baud_pulse <= 0;
      end
end


initial begin

data_input = 8'h41;
clk = 0;
send_data = 0;
baud_pulse = 0;

#20;
send_data = 1;
#500;
send_data = 0;

#100000;

$finish;

end

endmodule
