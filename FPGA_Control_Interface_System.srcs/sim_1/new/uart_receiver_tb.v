`timescale 1ns / 1ps

module uart_receiver_tb;

reg clk;
reg rx_in;

wire[7:0] data_received;

uart_receiver dut (
    .clk(clk),
    .rx_in(rx_in),
    .data_received(data_received)
);

reg[7:0] test_input = 8'h41;
integer i;

always 
#5 clk = ~clk;

initial begin

clk = 0;
rx_in = 1;

repeat(100) @(posedge clk);

rx_in = 0;
repeat(868) @(posedge clk);

for (i = 0; i < 8; i = i + 1) begin
    rx_in = test_input[i];
    repeat(868) @(posedge clk);
end

rx_in = 1;
repeat(868) @(posedge clk); 

$finish;

end

endmodule
