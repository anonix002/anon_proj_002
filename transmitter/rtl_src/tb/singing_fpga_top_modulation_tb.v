`timescale 1ns/100ps

module singing_fpga_top_modulation_tb;

    // Declarations
    reg  M_CLK_OSC;
    reg  M_RESET_B;
    reg  uart_rx;
    wire uart_tx;
    wire M_HEADER;
    wire M_LED_0;
    wire M_LED_1;
    wire M_LED_2;
    wire M_LED_3;

    localparam symbol_time = 17631; // Approx 57600 baud at 48MHz clock

    // DUT instantiation
    singing_fpga_top_aes_fsk_modulation dut (
    .M_CLK_OSC(M_CLK_OSC),
    .M_RESET_B(M_RESET_B),
    .FTDI_BDBUS_0(uart_rx),
    .FTDI_BDBUS_1(uart_tx),
    .M_HEADER(M_HEADER),
    .M_LED_0(M_LED_0),
    .M_LED_1(M_LED_1),
	 .M_LED_2(M_LED_2),
    .M_LED_3(M_LED_3)
);

	task send_uart_byte;
		input [7:0] in_byte;
	begin 
		//$display("sending byte %0h", in_byte);
		repeat (4) @(posedge M_CLK_OSC);
		#(symbol_time) uart_rx = 1'b0; // start bit
		#(symbol_time) uart_rx = in_byte[0];
		#(symbol_time) uart_rx = in_byte[1];
		#(symbol_time) uart_rx = in_byte[2];
		#(symbol_time) uart_rx = in_byte[3];
		#(symbol_time) uart_rx = in_byte[4];
		#(symbol_time) uart_rx = in_byte[5];
		#(symbol_time) uart_rx = in_byte[6];
		#(symbol_time) uart_rx = in_byte[7];
		#(symbol_time) uart_rx = 1'b1; // stop bit
		repeat (4) @(posedge M_CLK_OSC);
		repeat (40) @(posedge M_CLK_OSC);

	end
	endtask

    // clock generation
	always #(20.8333/2) M_CLK_OSC = ~M_CLK_OSC; // 48 MHz clock

    // Test sequence

	integer i;
	
	initial begin
		M_CLK_OSC = 0;
		M_RESET_B = 0;
		uart_rx = 1;
		repeat (4) @(posedge M_CLK_OSC);

		M_RESET_B = 1;
	
	
        for (i = 0; i < 4; i = i + 1) begin
          send_uart_byte(8'hDE);
		    send_uart_byte(8'hAD);
		    send_uart_byte(8'hBE);
		    send_uart_byte(8'hEF);
        end

        send_uart_byte(8'd00); // symbol time MSB
        send_uart_byte(8'd10); // symbol time LSB
		  
		send_uart_byte(8'd1); // repetition factor
	
	
		repeat (100000) @(posedge M_CLK_OSC);

		$finish;


	end


endmodule