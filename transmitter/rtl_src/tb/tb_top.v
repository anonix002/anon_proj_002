`timescale 1 ns / 100 ps

/**
 * Testbench for singing_fpga_top.v
 * Tests multi-frequency RF generation with software-selectable outputs
 * 
 * Protocol: 2-byte UART commands
 *   OFF: 0x0000
 *   ON:  0xFF + frequency_code
 * 
 * Frequency codes:
 *   0x00: 12 kHz
 *   0x01: 50 kHz
 *   0x02: 120 kHz
 *   0x03: 12 MHz
 *   0x04: 55.386 MHz
 *   0x05: 120 MHz
 *   0x06: 240 MHz
 *   0x07: 360 MHz
 */

module tb_top;
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

	// Instantiate DUT
	singing_fpga_top dut (
		.M_CLK_OSC    (clk),
		.M_RESET_B    (rst_n),
		.FTDI_BDBUS_0 (rx),
		.FTDI_BDBUS_1 (tx),
		.M_HEADER     (M_HEADER),
		.M_LED_0      (M_LED_0),
		.M_LED_1      (M_LED_1),
		.M_LED_2      (M_LED_2)
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
	 * Send a 2-byte command (command format: 0xFF + frequency_code or 0x0000 for off)
	 */
	task send_command;
		input [7:0] byte1;
		input [7:0] byte2;
	begin
		$display("\n[%0t] >>> Command: 0x%02H%02H", $time, byte1, byte2);
		send_uart_byte(byte1);
		send_uart_byte(byte2);
		#(100000); // Wait for processing
	end
	endtask

	/**
	 * Monitor LED status
	 */
	task report_leds;
	begin
		$display("[%0t]    LEDs: M_LED_0=%b (osc_active), M_LED_1=%b (pll_locked), M_LED_2=%b (reset)", 
			$time, M_LED_0, M_LED_1, M_LED_2);
	end
	endtask

	initial begin
		// Initialize signals
		clk = 0;
		rst_n = 0;
		rx = 1'b1; // Idle state (high)
		
		$display("\n========== SINGING FPGA TOP - TESTBENCH ==========");
		$display("[%0t] Initializing...", $time);
		
		// Reset phase
		repeat (10) @(posedge clk);
		rst_n = 1;
		$display("[%0t] Reset deasserted", $time);
		
		repeat (1000) @(posedge clk); // Let PLL stabilize
		$display("[%0t] PLL stabilization complete", $time);
		report_leds();
		
		// ============ TEST 1: Enable 12 kHz ============
		send_command(8'hFF, 8'h00); // 12 kHz
		report_leds();
		
		// ============ TEST 2: Enable 50 kHz ============
		send_command(8'hFF, 8'h01); // 50 kHz
		report_leds();
		
		// ============ TEST 3: Enable 120 kHz ============
		send_command(8'hFF, 8'h02); // 120 kHz
		report_leds();
		
		// ============ TEST 4: Enable 12 MHz ============
		send_command(8'hFF, 8'h03); // 12 MHz
		report_leds();
		
		// ============ TEST 5: Enable 55.386 MHz ============
		send_command(8'hFF, 8'h04); // 55.386 MHz
		report_leds();
		
		// ============ TEST 6: Enable 120 MHz ============
		send_command(8'hFF, 8'h05); // 120 MHz
		report_leds();
		
		// ============ TEST 7: Enable 240 MHz ============
		send_command(8'hFF, 8'h06); // 240 MHz
		report_leds();
		
		// ============ TEST 8: Enable 360 MHz ============
		send_command(8'hFF, 8'h07); // 360 MHz
		report_leds();
		
		// ============ TEST 9: Disable (OFF) ============
		send_command(8'h00, 8'h00); // OFF
		report_leds();
		
		// ============ TEST 10: Re-enable 12 MHz ============
		send_command(8'hFF, 8'h03); // 12 MHz (verify cycling)
		report_leds();
		
		// Final wait and finish
		$display("\n[%0t] All tests complete", $time);
		repeat (10000) @(posedge clk);
		$finish;
	end

	// Optional: VCD dump for waveform analysis
	// initial begin
	// 	$dumpfile("tb_top.vcd");
	// 	$dumpvars(0, tb_top);
	// end

endmodule
