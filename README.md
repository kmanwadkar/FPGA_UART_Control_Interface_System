# FPGA UART Control Interface System

An FPGA-based UART command processing system built in Verilog. The design implements a communication pipeline that receives serial commands from a PC, parses and executes them, and transmits responses back over UART.

## Features

- Custom UART RX/TX implementation in Verilog
- FSM-based byte sampling and transmission
- Command-based interface over serial terminal 
- Supports ASCII-based command protocol

## Supported Commands

### LED Control
Turn board LED on or off
### Read Switches
Read 16 board switches and transmit back to PC
### Status
Return status of board LED and switches 
### Echo
Echo back the written message

## Modules

### uart_receiver
- Samples incoming serial data
- Assembles bytes 

### command_buffer
- Stores incoming ASCII characters
- Detects newline termination 
- Outputs complete command string

### parse_data
- Decodes ASCII commands
- Identifies command type and arguments

### dispatch
- Executes command logic
- Controls LED output
- Prepares response data

### uart_tx_controller
- Streams bytes to UART transmitter
- Handles multi-byte transmission sequencing

### uart_transmitter
- Converts bytes into UART serial output
- Handles start/data/stop bits

### baud_rate
- Generates baud tick pulses for UART timing (115200 baud)
