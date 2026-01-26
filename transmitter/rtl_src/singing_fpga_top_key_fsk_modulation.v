module singing_fpga_top_key_fsk_modulation (
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
    (* keep = "true" *) wire [19*8-1:0] uart_rx_bus;    // 19 bytes received from UART (bitstring[127:0] | symbol_time[15:0] | rep_factor[7:0])
    (* keep = "true" *) wire uart_rx_valid;         // Valid signal from UART

    wire uart_tx_complete;  // UART transmission complete
    wire uart_tx_busy;      // UART busy signal

    reg [15:0] uart_tx_bus;      // 2 bytes to transmit via UART
    reg uart_tx_start;

    wire pll_locked;

    wire clk_12mhz_int;
    wire pll_clk_out;
    reg ready_flag;

    wire output_fsk;
    wire freq_select; // 0 for 888mhz, 1 for 936mhz

    // FSK modulator signals
    reg [127:0] fsk_bitstream;
    reg [15:0] fsk_symbol_time;
    reg fsk_start;
    reg [3:0] rep_factor;
    wire fsk_done;

    // State machine signals
    (* keep = "true" *) (* mark_debug = "TRUE"*) reg [1:0] state;
    (* keep = "true" *) (* mark_debug = "TRUE"*) wire wave_enable;         // Enable signal for wave generator

    // State definitions
    localparam IDLE = 2'b00;
    localparam MODULATE = 2'b10;
	 
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

    // pll_912 pll_912_inst (
    //     .CLK_IN1(buffered_clk_48mhz_out),

    //     .CLK_OUT1(pll_clk_out_zero), // 912mhz

    //     .RESET(freq_select || ~wave_enable),
    //     .LOCKED(pll_888_locked)
    //  );
     
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
        .bytes_to_receive(19),
        .bytes_to_transmit(2)
    ) inst_uart_interface (
        .clk(clk_12mhz_int),
        .reset(~M_RESET_B),
        .ser_in(FTDI_BDBUS_0),
        .ser_out(FTDI_BDBUS_1),
        .bus_SERDES(uart_rx_bus), // UART RX 
        .ciphertext(uart_tx_bus), // UART TX
        .valid_in(uart_rx_valid),
        .start_tx(uart_tx_start),
        .txFinish(uart_tx_complete),
        .eot(uart_tx_busy)
    );

    // FSK modulator instantiation
    modulator mod_inst (
        .clk(clk_12mhz_int),
        .reset(~M_RESET_B),
        .in_bitstream(fsk_bitstream),
        .symbol_time(fsk_symbol_time),
        .repetition_factor(rep_factor),
        .start(fsk_start),
        .done(fsk_done),
        .wave_enable(wave_enable),
        .out(freq_select)
    );

   // State machine
    always @(posedge clk_12mhz_int or negedge M_RESET_B) begin
        if (!M_RESET_B) begin
            state <= IDLE;
            fsk_start <= 1'b0;
            fsk_bitstream <= 128'd0;
            fsk_symbol_time <= 16'd0;
            uart_tx_start <= 1'b0;
            uart_tx_bus <= 16'd0;
            rep_factor <= 4'd0;
        end
        else begin
            case (state)
                IDLE: begin
                    uart_tx_start <= 1'b0;
                    if (uart_rx_valid) begin
                        fsk_bitstream   <= uart_rx_bus[19*8-1:3*8]; // First 16 bytes for bitstream
                        fsk_symbol_time <= uart_rx_bus[3*8-1:1*8];    // Last 2 bytes for symbol time
                        rep_factor      <= uart_rx_bus[3:0];    // Last byte for repetition factor
                        state <= MODULATE;
                    end 
                end
                
				MODULATE: begin
                    fsk_start <= 1'b1;
                    if (fsk_done) begin
                        fsk_start <= 1'b0;
                        uart_tx_start <= 1'b1;
                        uart_tx_bus <= 16'hAAAA; // Transmission complete signal
                        state <= IDLE;
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
