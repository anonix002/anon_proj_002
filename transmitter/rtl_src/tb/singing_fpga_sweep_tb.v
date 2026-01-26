`timescale 1 ns / 100 ps
module singing_fpga_sweep_tb;
	parameter BAUD_RATE = 57600;
	parameter PARITY_BIT = 0;
	parameter STOP_BIT = 1;
	parameter NANO_CONV = 1000000000;
	parameter bytes_to_receive = 2;
	parameter bytes_to_transmit = 3;
	parameter symbol_time = 17361.1;
	parameter data_width = 16;
	reg clk;
	reg rst_n;
	reg rx;
	wire tx;
	wire M_HEADER;	
	wire M_LED_0;
	wire M_LED_1;
	wire M_LED_2;
	
	singing_fpga_top_sweep
	dut (
		.M_CLK_OSC    (clk),
		.M_RESET_B    (rst_n),
		.FTDI_BDBUS_0 (rx),
		.FTDI_BDBUS_1 (tx),
		.M_HEADER     (M_HEADER),
		.M_LED_0 	  (M_LED_0),
		.M_LED_1 	  (M_LED_1),
		.M_LED_2 	  (M_LED_2)
	);

	task send_uart_byte;
		input [7:0] in_byte;
		input [31:0] symbol_time = 17631;
	begin 
		//$display("sending byte %0h", in_byte);
		repeat (4) @(posedge clk);
		#(symbol_time) rx = 1'b0; // start bit
		#(symbol_time) rx = in_byte[0];
		#(symbol_time) rx = in_byte[1];
		#(symbol_time) rx = in_byte[2];
		#(symbol_time) rx = in_byte[3];
		#(symbol_time) rx = in_byte[4];
		#(symbol_time) rx = in_byte[5];
		#(symbol_time) rx = in_byte[6];
		#(symbol_time) rx = in_byte[7];
		#(symbol_time) rx = 1'b1; // stop bit
		repeat (4) @(posedge clk);
		repeat (40) @(posedge clk);

	end
	endtask

	always #(20.8333/2) clk = ~clk;

	initial begin
		clk = 0;
		rst_n = 0;
		rx = 1;
		repeat (4) @(posedge clk);

		rst_n = 1;
	
		send_uart_byte(8'h00, 17631);
		send_uart_byte(8'h00, 17631);
		
		send_uart_byte(8'h00, 17631);
		send_uart_byte(8'h01, 17631);
		
		send_uart_byte(8'h00, 17631);
		send_uart_byte(8'h02, 17631);
	
		repeat (100000) @(posedge clk);

		$finish;


	end
endmodule
