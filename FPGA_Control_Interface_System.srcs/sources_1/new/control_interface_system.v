`timescale 1ns / 1ps

module control_interface_system(
    input clk,
    input reset,
    input rx_in,
    input [15:0] switches,
    output tx_out,
    output led_on
    );
    //receive wires
    wire [7:0] rx_data;
    wire command_ready;
    wire [6:0] command_length;
    wire [511:0] command_buffer;

    wire valid_command;
    wire [1:0] command_type;
    wire [7:0] command_argument_num;
    wire [511:0] command_argument_text;
    wire [6:0] command_argument_text_length;
    wire parsed_ready;
    
    //transmit wires
    wire transmit_request;
    wire [511:0] transmit_text;
    wire [6:0] transmit_length;
    wire [1:0] transmit_type;

    wire send_data;
    wire [7:0] tx_data;
    wire tx_busy;

    wire baud_pulse;
    wire baud_reset;
    
    uart_receiver RX (.clk(clk), .rx_in(rx_in), .reset(reset), .data_received(rx_data));
    command_buffer CB (.clk(clk), .rx_incoming(rx_in), .rx_data(rx_data), .reset(reset), .command_ready(command_ready), .command_length(command_length), .command_buffer(command_buffer));
    
    parse_data PARSER (.clk(clk), .reset(reset), .command_ready(command_ready), .command_length(command_length), .command_buffer(command_buffer),
      .valid_command(valid_command), .command_type(command_type), .command_argument_num(command_argument_num), .command_argument_text(command_argument_text),
       .command_argument_text_length(command_argument_text_length), .parsed_ready(parsed_ready));
    
    dispatch DSP (.clk(clk), .reset(reset), .parsed_ready(parsed_ready), .valid_command(valid_command), .command_type(command_type), .command_argument_num(command_argument_num),
      .command_argument_text(command_argument_text), .command_argument_text_length(command_argument_text_length), .switches(switches), .led_on(led_on), .transmit_request(transmit_request),
        .transmit_text(transmit_text), .transmit_length(transmit_length), .transmit_type(transmit_type));

    uart_tx_controller TX_CTRL (.clk(clk), .reset(reset), .transmit_request(transmit_request), .tx_busy(tx_busy), .transmit_type(transmit_type), .transmit_length(transmit_length),
        .transmit_text(transmit_text), .send_data(send_data), .data_input(tx_data));
        
    baud_rate BAUD (.clk(clk), .baud_reset(baud_reset), .baud_pulse(baud_pulse));
    
    uart_transmitter UART_TX (.clk(clk), .send_data(send_data), .baud_pulse(baud_pulse), .data_input(tx_data), .reset(reset), .baud_reset(baud_reset),.tx_out(tx_out), .tx_busy(tx_busy));

endmodule

//////////////////////////////////////////////////////////////////
module uart_receiver(
input wire clk,
input wire rx_in,
input reset, 
output reg[7:0] data_received
    );
    
parameter IDLE  = 3'b000;
parameter START = 3'b001;
parameter WAIT  = 3'b010;
parameter SAMPLE  = 3'b011;
parameter STOP = 3'b100;

reg[8:0] half_counter = 0;
reg[9:0] counter = 0;
reg[3:0] data_length = 8;
reg[7:0] data = 0;

reg[2:0] state = IDLE;
reg[2:0] next_state;

//combination state logic
always @(*) begin
    next_state = state;
    case(state)
        IDLE: begin
            if (rx_in == 0)
                next_state = START;
          end
        START: begin
            if (half_counter >= 433)
                next_state = WAIT;
          end
        WAIT: begin
            if (counter >= 867)
                next_state = SAMPLE;
          end
        SAMPLE: begin   
            if (data_length > 1)
                next_state = WAIT;
            else 
                next_state = STOP;
          end
       STOP: begin
            if (rx_in == 1)
                next_state = IDLE;
          end
    endcase
   end

//sequential state change and register logic 
 always @(posedge clk) begin
 
    if (reset) begin
        half_counter <= 0;
        counter <= 0;
        data_length <= 4'd8;
        data <= 0;
        data_received <= 0;
        state <= IDLE;
      end
    else begin
       
    state <= next_state;
    
    case(state) 
        IDLE: begin
            half_counter <= 0;
            counter <= 0;
            data_length <= 4'd8;
            data <= 0;
          end
        START: begin
            counter <= 0;
            half_counter <= half_counter + 1;
          end
        WAIT: begin
            counter <= counter + 1;
            half_counter <= 0;  
          end
        SAMPLE: begin
            data <= {data[6:0], rx_in};
            counter <= 0;
            data_length <= data_length - 1;
         end
        STOP: begin
            data_received <= data;
         end     
       
    endcase
    
   end
  end 
   
endmodule

//////////////////////////////////////////////////////////////////
module uart_transmitter(
input wire clk,
input wire send_data,
input wire baud_pulse,
input wire[7:0] data_input,
input reset,
output reg baud_reset,
output reg tx_out,
output reg tx_busy 
    );
    
parameter IDLE  = 2'b00;
parameter START = 2'b01;
parameter TRANSMIT = 2'b10;
parameter STOP = 2'b11;

reg[3:0] data_length = 0;
reg[7:0] data_in = 0;

reg[1:0] state = IDLE;
reg[1:0] next_state;

//combinational state logic
always @(*) begin
    next_state =  state;
        
    case (state)
        IDLE: begin
            if (send_data)
                next_state = START;
          end
        START: begin
            next_state = TRANSMIT;
          end
        TRANSMIT: begin
            if (data_length == 7)
                next_state = STOP;
          end
        STOP: begin
            next_state = IDLE;
         end
    endcase  
 end
 
always @(*) begin
    baud_reset = (state == IDLE);
end
 
//sequential state change and register logic 
 always @(posedge clk) begin    
 
   if (reset) begin
       tx_out <= 1;
       tx_busy <= 0;
       data_length <= 0;
       data_in <= 0;
       state <= IDLE;
   end
   else if (state == IDLE) begin
        tx_out <= 1;
        tx_busy <= 0;
        data_length <= 0;
        if (send_data) begin
            data_in <= data_input;
            state <= START;
          end
   end  
       
   else if (baud_pulse) begin
    state <= next_state;

    case(state) 
        START: begin
            tx_out <= 0;
            tx_busy <= 1;
          end
        TRANSMIT: begin
            tx_out <= data_in[data_length];
            data_length <= data_length + 1;
            tx_busy <= 1;
          end
        STOP: begin
            tx_out <= 1;
            tx_busy <= 0;
          end    
     endcase
     end
 end           

endmodule

//////////////////////////////////////////////////////////////////
module baud_rate(
    input clk, 
    input baud_reset,
    output reg baud_pulse
    );

reg[9:0] counter = 0;

always @(posedge clk) begin
    if (baud_reset) begin
        counter <= 0;
        baud_pulse <= 0;
      end
    else if (counter == 10'd867) begin
        counter <= 0;
        baud_pulse <= 1;
      end
    else begin
        counter <= counter + 10'd1;
        baud_pulse <= 0;
      end
end

endmodule

//////////////////////////////////////////////////////////////////
module command_buffer(
input clk,
input rx_incoming,
input[7:0] rx_data,
input reset,
output reg command_ready,
output reg[6:0] command_length,
output reg [511:0] command_buffer
);

parameter IDLE = 2'b00;
parameter PROCESS = 2'b01;
parameter STOP = 2'b10;

reg[6:0] ptr;
reg[1:0] state = IDLE;
reg[1:0] next_state;
integer i;

//combinational state logic 
always @(*) begin
    next_state = state;
    
    case(state) 
        IDLE: begin
            if (rx_incoming)
                next_state = PROCESS;
          end
        PROCESS: begin
            if ((rx_incoming) && (rx_data == 8'h0A))
                next_state = STOP;
          end
        STOP: begin
            next_state = IDLE;
          end
    endcase
end

always @(posedge clk) begin

   if (reset) begin
        state <= IDLE;
        ptr <= 0;
        command_ready <= 0;
        command_length <= 0;
    end
    
   else begin
    state <= next_state;
    command_ready <= 0;
    
    case(state)
        IDLE: begin
            ptr <= 0;
            command_ready <= 0;
            command_length <= 0;
            for (i = 0; i < 64; i = i + 1) begin
                command_buffer[i*8 +: 8] <= 0;
            end
          end
        PROCESS: begin
            if (rx_incoming) begin
                if (rx_data == 8'h0A) begin
                    command_length <= ptr;
                  end
            else begin
                if (ptr < 64) begin
                    command_buffer[ptr*8 +: 8] <= rx_data;
                    ptr <= ptr + 1;
                  end
              end  
            end
         end
        STOP: begin
            command_ready <= 1;
          end
     endcase 
   end  
end  
endmodule

//////////////////////////////////////////////////////////////////
module parse_data(
input clk, 
input reset,
input command_ready,
input [6:0] command_length,
input [511:0] command_buffer,

output reg valid_command,
output reg[1:0] command_type,
output reg[7:0] command_argument_num,
output reg[511:0] command_argument_text,
output reg[6:0] command_argument_text_length,
output reg parsed_ready
    );

integer k;
integer i;
integer j = 0;

always @(posedge clk) begin
   
   if (reset) begin
        valid_command <= 0;
        command_type <= 0;
        command_argument_num <= 0;
        command_argument_text_length <= 0;
        parsed_ready <= 0;
        j <= 0;
        k <= 0;
        i <= 0;
     end
     
   else if (command_ready) begin
        case(command_buffer[0*8+:8])
            "L": begin
                if ((command_buffer[1*8+:8] == "E") && (command_buffer[2*8+:8] == "D")) begin
                    if ((command_buffer[3*8+:8] == " ") && (command_buffer[4*8+:8] == "O") && (command_buffer[5*8+:8] == "N")) begin
                        command_type <= 0;
                        command_argument_num <= 0;
                        parsed_ready <= 1;
                        valid_command <= 1;
                      end
                    else if ((command_buffer[3*8+:8] == " ") && (command_buffer[4*8+:8] == "O") && (command_buffer[5*8+:8] == "F") && (command_buffer[6*8+:8] == "F")) begin
                        command_type <= 0;
                        command_argument_num <= 1;
                        parsed_ready <= 1;
                        valid_command <= 1;
                      end
                end
              end
             
            "S": begin
                if ((command_buffer[1*8+:8] == "T") && (command_buffer[2*8+:8] == "A")) begin
                    if ((command_buffer[3*8+:8] == "T") && (command_buffer[4*8+:8] == "U") && (command_buffer[5*8+:8] == "S")) begin
                        command_type <= 1;
                        parsed_ready <= 1;
                        valid_command <= 1;
                      end
                  end
              end
              
            "R": begin
                if ((command_buffer[1*8+:8] == "E") && 
                    (command_buffer[2*8+:8] == "A") &&
                    (command_buffer[3*8+:8] == "D") &&
                    (command_buffer[4*8+:8] == " ") &&
                    (command_buffer[5*8+:8] == "S") &&
                    (command_buffer[6*8+:8] == "W") &&
                    (command_buffer[7*8+:8] == "I") &&
                    (command_buffer[8*8+:8] == "T") &&
                    (command_buffer[9*8+:8] == "C") &&
                    (command_buffer[10*8+:8] == "H") &&
                    (command_buffer[11*8+:8] == "E") &&
                    (command_buffer[12*8+:8] == "S")) begin
                    command_type <= 2;
                    parsed_ready <= 1;
                    valid_command <= 1;
                    end 
              end
              
            "E": begin
                if ((command_buffer[1*8+:8] == "C") && (command_buffer[2*8+:8] == "H") && (command_buffer[3*8+:8] == "O")) begin
                    command_type <= 3;
                    if (command_buffer[4*8+:8] == " ") begin
                        for (i = 5; i < command_length; i = i + 1) begin
                            command_argument_text[j*8+:8] <= command_buffer[i*8+:8];
                            j <= j + 1;
                          end
                          j <= 0;
                         parsed_ready <= 1;
                         command_argument_text_length <= command_length - 5;
                         valid_command <= 1;
                      end 
                 end
              end 
           endcase
           parsed_ready <= 1;
        end
     end     
     
endmodule

//////////////////////////////////////////////////////////////////

module dispatch(
input clk,
input reset,
input parsed_ready,
input valid_command,
input [1:0] command_type,
input [7:0] command_argument_num,
input [511:0] command_argument_text,
input [6:0] command_argument_text_length,
input [15:0] switches,

output reg led_on,
output reg transmit_request,
output reg[511:0] transmit_text,
output reg[6:0] transmit_length,
output reg[1:0] transmit_type
);

integer i;

parameter STATUS  = 0;
parameter SWITCHES  = 1;
parameter ECHO    = 2;
parameter INVALID = 3;

always @(posedge clk) begin
transmit_request <= 0;

if (reset) begin
    led_on <= 0;
    transmit_request <= 0;
    transmit_length <= 0;
    for (i = 0; i < 32; i = i + 1) begin
        transmit_text[i*8+:8] <= 0;
      end
  end
  
else if (parsed_ready) begin
    if (valid_command == 1) begin
        case (command_type)
           0: begin //LED 
              transmit_request <= 0;
              if (command_argument_num == 0) begin
                   led_on <= 1;
                end 
              else 
                   led_on <= 0;
             end
           1: begin //STATUS            
                transmit_text[0*8+:8] <= "S";
                transmit_text[1*8+:8] <= "W";
                transmit_text[2*8+:8] <= "I";
                transmit_text[3*8+:8] <= "T";
                transmit_text[4*8+:8] <= "C";
                transmit_text[5*8+:8] <= "H";
                transmit_text[6*8+:8] <= "E";
                transmit_text[7*8+:8] <= "S";
                transmit_text[8*8+:8] <= " ";
                for (i = 9; i < 25; i = i + 1) begin
                    if (switches[i - 9] == 1)
                        transmit_text[i*8+:8] <= "1";
                    else
                        transmit_text[i*8+:8] <= "0";
                end
                transmit_text[25*8+:8] <= "\n";
                transmit_text[26*8+:8] <= "L";
                transmit_text[27*8+:8] <= "E";
                transmit_text[28*8+:8] <= "D";
                transmit_text[29*8+:8] <= " ";
                if (led_on == 1) begin
                    transmit_text[30*8+:8] <= "O";
                    transmit_text[31*8+:8] <= "N";
                  end
                else begin  
                    transmit_text[30*8+:8] <= "O";
                    transmit_text[31*8+:8] <= "F";
                    transmit_text[32*8+:8] <= "F";
                  end  
                transmit_request <= 1;
                transmit_length <= 33;
                transmit_type <= STATUS;
             end      
           2: begin //READ SWITCHES        
                for (i = 0; i < 16; i = i + 1) begin
                    if (switches[i] == 1)
                        transmit_text[i*8+:8] <= "1";
                    else
                        transmit_text[i*8+:8] <= "0";
                  end
                transmit_length <= 16;
                transmit_request <= 1;
                transmit_type <= SWITCHES;
             end
           3: begin //ECHO
                for (i = 0; i < command_argument_text_length; i = i + 1) begin
                    transmit_text[i*8+:8] <= command_argument_text[i*8+:8];
                  end
                transmit_length <= command_argument_text_length;
                transmit_request <= 1;
                transmit_type <= ECHO;
             end     
        endcase
      end
    else begin
    //transmit "Invalid command; check valid commands and formatting" to PC 
      transmit_request <= 1;
      transmit_text[0*8+:8] <= "I";
      transmit_text[1*8+:8] <= "N";
      transmit_text[2*8+:8] <= "V";
      transmit_text[3*8+:8] <= "A";
      transmit_text[4*8+:8] <= "L";
      transmit_text[5*8+:8] <= "I";
      transmit_text[6*8+:8] <= "D";
      transmit_text[7*8+:8] <= " ";
      transmit_text[8*8+:8] <= "I";
      transmit_text[9*8+:8] <= "N";
      transmit_text[10*8+:8] <= "P";
      transmit_text[11*8+:8] <= "U";
      transmit_text[12*8+:8] <= "T";
      transmit_length <= 13;
      end
  end 
  
end
endmodule

////////////////////////////////////////////////////////////////////////////

module uart_tx_controller(
input clk, 
input reset, 
input transmit_request,
input tx_busy,
input [1:0] transmit_type, 
input [6:0] transmit_length,
input [511:0] transmit_text,

output reg send_data,
output reg[7:0] data_input
);

reg[6:0] index = 0;

reg[1:0] state = IDLE;
reg[1:0] next_state;

parameter IDLE = 2'b00;
parameter PROCESS = 2'b01;
parameter WAIT = 2'b10;

//combinational state logic
always @(*) begin

next_state = state;

case(state) 
    IDLE: begin
        if (transmit_request == 1)
            next_state = PROCESS;
      end
    PROCESS: begin
        next_state = WAIT;
      end
    WAIT: begin
        if ((tx_busy == 0) && (index < transmit_length))
            next_state = PROCESS;
        else if ((tx_busy == 0) && (index >= transmit_length))
            next_state = IDLE;
        else 
            next_state = WAIT;
      end
  endcase
end

//sequential state transition and register logic
always @(posedge clk) begin

if (reset) begin
    send_data <= 0;
    data_input <= 0;
    index <= 0;
    state <= IDLE;
  end
else begin

state <= next_state;

case(state)
    IDLE: begin
        send_data <= 0;
        data_input <= 0;
        index <= 0;
      end
    PROCESS: begin
        data_input <= transmit_text[index*8+:8];
        send_data <= 1;
        index <= index + 1;
      end      
    WAIT: begin
        send_data <= 0;   
      end
endcase
end

end 
endmodule
