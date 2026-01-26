module singing_fpga_top_sweep (
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
    output M_LED_2
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

    //    (* S = "TRUE"*) pll_12_600 my_pll (
    //        .CLK_IN1(M_CLK_OSC),
    //
    //        .CLK_OUT1(clk_12mhz_int), // 12mhz
    //        .CLK_OUT2(pll_clk_out), // 600mhz
    //
    //        .RESET(~M_RESET_B),
    //        .LOCKED(pll_locked)
    //    );

    //    (* S = "TRUE"*) pll_12_648 my_pll (
    //        .CLK_IN1(M_CLK_OSC),
    //
    //        .CLK_OUT1(clk_12mhz_int), // 12mhz
    //        .CLK_OUT2(pll_clk_out), // 648mhz
    //
    //        .RESET(~M_RESET_B),
    //        .LOCKED(pll_locked)
    //     );

    //   (* S = "TRUE"*) pll_12_648 my_pll (
    //      .CLK_IN1(M_CLK_OSC),

    //      .CLK_OUT1(clk_12mhz_int), // 12mhz
    //      .CLK_OUT2(pll_clk_out), // 936mhz

    //      .RESET(~M_RESET_B),
    //      .LOCKED(pll_locked)
    //  );
	 
	 wire buffered_clk_48mhz_out;
	 
		IBUFG input_clk_buffer (
		.I(M_CLK_OSC),
		.O(buffered_clk_48mhz_out)
		);
     
     (* S = "TRUE"*) pll_12 pll_12_inst (
         .CLK_IN1(buffered_clk_48mhz_out),

         .CLK_OUT1(clk_12mhz_int), // 12mhz

         .RESET(~M_RESET_B),
         .LOCKED()
     );
     
     (* S = "TRUE"*) pll_936 pll_936_inst (
         .CLK_IN1(buffered_clk_48mhz_out),

         .CLK_OUT1(pll_clk_out), // 936mhz

         .RESET(~wave_enable),
         .LOCKED(pll_locked)
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

    // Square wave generator instantiation
    (* S = "TRUE"*) (* dont_touch = "TRUE" *) square_wave_generator inst_square_wave_generator (
        .clk(pll_clk_out),
        .reset_n(M_RESET_B),
        .enable(1'b1),   
        .bypass(bypass_division), // Bypass signal to output the original clock 
        .T(wave_period),
        .square_out(wave_out)
    );

   // State machine
    always @(posedge clk_12mhz_int or negedge M_RESET_B) begin
        if (!M_RESET_B) begin
            state <= IDLE;
            wave_period <= 16'd0;
            wave_enable <= 1'b0;
			ready_flag <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    wave_enable <= 1'b0;
					ready_flag <= 1'b0;
                    if (uart_data_valid) begin
                        wave_period <= uart_data_bus;  // Division factor T
						state <= WAIT_READY_ZERO;
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
    assign M_LED_1 = pll_locked;
    assign M_LED_2 = M_RESET_B;

    assign bypass_division = (wave_period == 16'hFFFF);
	 
    dipole_quad_full dipole_quad_full_inst (
      .antenna_in(wave_out)
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
