`timescale 1 ns / 100 ps

/**
 * Testbench for singing_fpga_top_basic_fsk_modulation.v
 * Tests binary FSK with software-selectable frequency (888 MHz or 936 MHz)
 * 
 * Protocol: 2-byte UART commands
 *   0x0000: Disable all oscillators
 *   LSB=0 (0x0001, 0x0003, etc.): Enable 888 MHz
 *   LSB=1 (0x0002, 0x0004, etc.): Enable 936 MHz
 * 
 * State machine behavior:
 *   IDLE → (valid data non-zero) → WAIT_READY_ZERO → (valid=0) → CONTINUOUS_WAVE
 *   CONTINUOUS_WAVE → (valid=1) → ready_flag=1 → (valid=0) → IDLE
 */

module singing_fpga_top_basic_fsk_tb;
	parameter BAUD_RATE = 57600;
	parameter CLK_PERIOD = 20.8333; // 48 MHz: 20.8333 ns
	parameter UART_BIT_TIME = 17361; // ns for 57600 baud
	
	reg clk;
	reg rst_n;
	reg rx;
	wire tx;
	wire M_HEADER;	
	wire M_LED_0;
	wire M_LED_1;
	wire M_LED_2;
	wire M_LED_3;

	// Instantiate DUT
	singing_fpga_top_basic_fsk_modulation dut (
		.M_CLK_OSC    (clk),
		.M_RESET_B    (rst_n),
		.FTDI_BDBUS_0 (rx),
		.FTDI_BDBUS_1 (tx),
		.M_HEADER     (M_HEADER),
		.M_LED_0      (M_LED_0),
		.M_LED_1      (M_LED_1),
		.M_LED_2      (M_LED_2),
		.M_LED_3      (M_LED_3)
	);

	// 48 MHz clock generation
	always #(CLK_PERIOD/2) clk = ~clk;

	/**
	 * Send a single UART byte at 57600 baud
	 * Format: 1 start bit, 8 data bits (LSB first), 1 stop bit, no parity
	 */
	task send_uart_byte;
		input [7:0] data_byte;
	begin
		$display("[%0t] UART TX: 0x%02H", $time, data_byte);
		
		// Start bit (low for 1 bit time)
		rx = 1'b0;
		#(UART_BIT_TIME);
		
		// Data bits (LSB first)
		rx = data_byte[0]; #(UART_BIT_TIME);
		rx = data_byte[1]; #(UART_BIT_TIME);
		rx = data_byte[2]; #(UART_BIT_TIME);
		rx = data_byte[3]; #(UART_BIT_TIME);
		rx = data_byte[4]; #(UART_BIT_TIME);
		rx = data_byte[5]; #(UART_BIT_TIME);
		rx = data_byte[6]; #(UART_BIT_TIME);
		rx = data_byte[7]; #(UART_BIT_TIME);
		
		// Stop bit (high for 1 bit time)
		rx = 1'b1;
		#(UART_BIT_TIME);
	end
	endtask

	/**
	 * Send a 2-byte command with LSB frequency selection
	 * LSB=0: 888 MHz, LSB=1: 936 MHz
	 */
	task send_fsk_command;
		input [7:0] byte1;
		input [7:0] byte2;
	begin
		$display("\n[%0t] >>> Command: 0x%02H%02H (LSB=%b)", $time, byte1, byte2, byte2[0]);
		send_uart_byte(byte1);
		send_uart_byte(byte2);
	    repeat (100) @(posedge clk); // Wait for processing
	end
	endtask

	/**
	 * Monitor LED status
	 */
	task report_leds;
	begin
		$display("[%0t]    LEDs: M_LED_0=%b (wave_enable), M_LED_1=%b (888_locked), M_LED_2=%b (936_locked), M_LED_3=%b (reset)", 
			$time, M_LED_0, M_LED_1, M_LED_2, M_LED_3);
	end
	endtask

	initial begin
		// Initialize signals
		clk = 0;
		rst_n = 0;
		rx = 1'b1; // Idle state (high)
		
		$display("\n========== SINGING FPGA BASIC FSK - TESTBENCH ==========");
		$display("[%0t] Initializing...", $time);
		
		// Reset phase
		repeat (10) @(posedge clk);
		rst_n = 1;
		$display("[%0t] Reset deasserted", $time);
		
		repeat (1000) @(posedge clk); // Let PLL stabilize
		$display("[%0t] PLL stabilization complete", $time);
		report_leds();
		
		// ============ TEST 1: Enable 888 MHz (LSB=0) ============
		send_fsk_command(8'hFF, 8'h00); // LSB=0
		report_leds();
		
		// ============ TEST 2: Enable 936 MHz (LSB=1) ============
		send_fsk_command(8'hFF, 8'h01); // LSB=1
		report_leds();
		
		// ============ TEST 3: Switch to 888 MHz (LSB=0) ============
		send_fsk_command(8'hFF, 8'h00); // LSB=0
		report_leds();
		
		// ============ TEST 4: Disable (0x0000) ============
		send_fsk_command(8'h00, 8'h00); // All zeros
		report_leds();
		
		// ============ TEST 5: Re-enable 936 MHz (LSB=1) ============
		send_fsk_command(8'hFF, 8'h01); // LSB=1
		report_leds();
		
		// Final wait and finish
		$display("\n[%0t] All tests complete", $time);
		repeat (10000) @(posedge clk);
		$finish;
	end

	// Optional: VCD dump for waveform analysis
	// initial begin
	// 	$dumpfile("singing_fpga_top_basic_fsk_tb.vcd");
	// 	$dumpvars(0, singing_fpga_top_basic_fsk_tb);
	// end

endmodule
