module singing_fpga_top_basic_fsk_modulation (
    /* Clock, Reset */
    input M_CLK_OSC,
    input M_RESET_B,
    /* UART interface */
    input FTDI_BDBUS_0,  // UART RX
    output FTDI_BDBUS_1, // UART TX
    /* HEADER & LEDs OUTPUT */
    output M_HEADER,
    output M_LED_0,
    output M_LED_1,
    output M_LED_2,
	output M_LED_3
);
    // Internal signals
    (* keep = "true" *) wire [15:0] uart_data_bus;    // 2 bytes received from UART
    (* keep = "true" *) wire uart_data_valid;         // Valid signal from UART

    wire uart_tx_complete;  // UART transmission complete
    wire uart_tx_busy;      // UART busy signal

    wire pll_locked;

    wire clk_12mhz_int;
    wire pll_clk_out;
    reg ready_flag;

    wire output_fsk;
    reg freq_select; // 0 for 888mhz, 1 for 936mhz

    // State machine signals
    (* keep = "true" *) (* mark_debug = "TRUE"*) reg [1:0] state;
    (* keep = "true" *) (* mark_debug = "TRUE"*) reg [15:0] wave_period;  // Store T value
    (* keep = "true" *) (* mark_debug = "TRUE"*) reg wave_enable;         // Enable signal for wave generator
    (* keep = "true" *) (* mark_debug = "TRUE"*) wire wave_out;           // Square wave output
    (* keep = "true" *) (* mark_debug = "TRUE"*) wire bypass_division;

    // State definitions
    localparam IDLE = 2'b00;
    localparam CONTINUOUS_WAVE = 2'b10;
	localparam WAIT_READY_ZERO = 2'b11;
	 
	 wire buffered_clk_48mhz_out;
	 
	IBUFG input_clk_buffer (
        .I(M_CLK_OSC),
        .O(buffered_clk_48mhz_out)
	);
     
    pll_936 pll_936_inst (
        .CLK_IN1(buffered_clk_48mhz_out),

        .CLK_OUT1(pll_clk_out_one), // 936mhz

        .RESET(~freq_select || ~wave_enable),
        .LOCKED(pll_936_locked)
     );

    pll_888 pll_888_inst (
        .CLK_IN1(buffered_clk_48mhz_out),

        .CLK_OUT1(pll_clk_out_zero), // 888mhz

        .RESET(freq_select || ~wave_enable),
        .LOCKED(pll_888_locked)
     );
     
    pll_12 pll_12_inst (
        .CLK_IN1(buffered_clk_48mhz_out),

        .CLK_OUT1(clk_12mhz_int), // 12mhz

        .RESET(~M_RESET_B),
        .LOCKED()
     );

    BUFG BUFG_one_inst (
        .O(pll_clk_out_one_buf), // 1-bit output: Clock buffer output
        .I(pll_clk_out_one) // 1-bit input: Clock buffer input
     );

     BUFG BUFG_zero_inst (
        .O(pll_clk_out_zero_buf), // 1-bit output: Clock buffer output
        .I(pll_clk_out_zero) // 1-bit input: Clock buffer input
     );

    // UART interface instantiation
    (* S = "TRUE"*) (* dont_touch = "TRUE" *)uart_interface #(
        .bytes_to_receive(2),
        .bytes_to_transmit(2)
    ) inst_uart_interface (
        .clk(clk_12mhz_int),
        .reset(~M_RESET_B),
        .ser_in(FTDI_BDBUS_0),
        .ser_out(FTDI_BDBUS_1),
        .bus_SERDES(uart_data_bus),
        .ciphertext(uart_data_bus),
        .valid_in(uart_data_valid),
        .start_tx(uart_data_valid),
        .txFinish(uart_tx_complete),
        .eot(uart_tx_busy)
    );

   // State machine
    always @(posedge clk_12mhz_int or negedge M_RESET_B) begin
        if (!M_RESET_B) begin
            state <= IDLE;
            // wave_period <= 16'd0;
            wave_enable <= 1'b0;
			ready_flag <= 1'b0;
            freq_select <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    wave_enable <= 1'b0;
					ready_flag <= 1'b0;
                    freq_select <= 1'b0;
                    if (uart_data_valid) begin
                        if (uart_data_bus != 16'd0) begin
                            freq_select <= uart_data_bus[0]; // LSB for frequency selection
                            state <= WAIT_READY_ZERO;
                        end
                        else
                            state <= IDLE; // Ignore 0 input
                    end 
                end
                
				WAIT_READY_ZERO: begin
					if (uart_data_valid == 0) begin
						wave_enable <= 1'b1;
                        state <= CONTINUOUS_WAVE;
					end
				end 

                CONTINUOUS_WAVE: begin
					if (uart_data_valid) begin  // Any new frame will stop the wave
						ready_flag <= 1'b1;
					end

					if (ready_flag) begin
						if (uart_data_valid == 0) begin
                            if (uart_data_bus != 16'd0) begin
                                freq_select <= uart_data_bus[0]; // LSB for frequency selection
                            end
                            else 
							    state <= IDLE;
						end
					end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Assign output to header
    assign M_HEADER = 1'b0;
    assign M_LED_0 = wave_enable;
    assign M_LED_1 = pll_888_locked;
    assign M_LED_2 = pll_936_locked;;
    assign M_LED_3 = M_RESET_B;
	 
    assign output_fsk = pll_clk_out_zero_buf || pll_clk_out_one_buf;

    dipole_quad_full dipole_quad_full_inst (
      .antenna_in(output_fsk && wave_enable)
   );

//	  full_snake full_snake_inst (
//        .antenna_in(wave_out)
//    );

// 	  full_spiral full_spiral_inst (
//        .antenna_in(wave_out)
//    );

// 	 fractal fractal_inst (
//        .antenna_in(wave_out)
//    );

//	 monopole_array monopole_array_inst (
//       .antenna_in(wave_out)
//   );

endmodule
