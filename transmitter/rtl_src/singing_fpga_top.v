module singing_fpga_top (
    /* Clock, Reset */
    input M_CLK_OSC,
    input M_RESET_B,
    /* UART interface */
    input FTDI_BDBUS_0,
    output FTDI_BDBUS_1,
    /* HEADER OUTPUT */
    output M_HEADER,
    output M_LED_0,
    output M_LED_1,
    output M_LED_2
);
    // Internal signals
    (* keep = "true" *) wire [15:0] uart_data_bus;       // 2 bytes received from UART
    (* keep = "true" *) wire uart_data_valid;            // Valid signal from UART

    wire uart_tx_complete;           // UART transmission complete
    wire uart_tx_busy;               // UART busy signal

    (* keep = "true" *) (* mark_debug = "TRUE"*) reg osc_en;  
    (* keep = "true" *) (* mark_debug = "TRUE"*) wire nand_out;

    wire pll_locked;

    // Clock signals
    wire clk_12mhz_int;

    reg clk_120khz_int = 1'b0; // 100kHz clock output
    reg clk_12khz_int = 1'b0; // 10kHz clock output
    reg clk_50khz_int = 1'b0; // 50kHz clock output

    wire clk_12mhz_antenna_int;
    wire clk_55_386mhz_int;
    wire clk_120mhz_int;
    wire clk_240mhz_int;
    wire clk_360mhz_int;

    // wire clk_4mhz_int;
    // wire clk_30mhz_int;
    // wire clk_75mhz_int;
    // wire clk_150mhz_int;
    // wire clk_300mhz_int;

    // Oscillator enable signals
    // reg osc_4_en = 1'b0;      // Enable signal for 4MHz oscillator
    // reg osc_30_en = 1'b0;     // Enable signal for 30MHz oscillator
    // reg osc_75_en = 1'b0;     // Enable signal for 75MHz oscillator
    // reg osc_150_en = 1'b0;    // Enable signal for 150MHz oscillator
    // reg osc_300_en = 1'b0;    // Enable signal for 300MHz oscillator

    reg osc_12khz_en = 1'b0; // Enable signal for 12kHz clock
    reg osc_50khz_en = 1'b0; // Enable signal for 120kHz clock
    reg osc_120khz_en = 1'b0; // Enable signal for 120kHz clock
    reg osc_12m_en = 1'b0; // Enable signal for 12MHz oscillator
    reg osc_55_386m_en = 1'b0; // Enable signal for 55.386MHz oscillator
    reg osc_120m_en = 1'b0;    // Enable signal for 120MHz oscillator
    reg osc_240m_en = 1'b0;    // Enable signal for 240MHz oscillator
    reg osc_360m_en = 1'b0;    // Enable signal for 360MHz oscillator

    // frequency divider from 12mhz to 120khz and 12khz
    reg [15:0] counter_120khz = 16'd0; // Counter for 120kHz
    reg [15:0] counter_50khz = 16'd0; // Counter for 50kHz
    reg [15:0] counter_12khz = 16'd0; // Counter for 12kHz

    assign clk_12mhz_antenna_int = clk_12mhz_int & osc_12m_en; // 12MHz clock for antenna
    
    // (* S = "TRUE"*) pll_12_75_ce my_pll (
    //     .CLK_IN1(M_CLK_OSC),
    //     .CLK_OUT1(clk_12mhz_int), // 12mhz
    //     .CLK_OUT2(clk_75mhz_int),
    //     .CLK_OUT2_CE(osc_en),
    //     .RESET(~M_RESET_B),
    //     .LOCKED(pll_locked)
    // );

    // (* S = "TRUE"*) pll_12_30_75_150_300_4_ce my_pll (
    //     .CLK_IN1(M_CLK_OSC),
    //     .CLK_OUT_12(clk_12mhz_int), // 12mhz

    //     .CLK_OUT_4(clk_4mhz_int), // 4mhz
    //     .CLK_OUT_4_CE(osc_4_en), // 4mhz enable

    //     .CLK_OUT_30(clk_30mhz_int), // 30mhz
    //     .CLK_OUT_30_CE(osc_30_en), // 30mhz enable

    //     .CLK_OUT_75(clk_75mhz_int), // 75mhz
    //     .CLK_OUT_75_CE(osc_75_en), // 75mhz enable

    //     .CLK_OUT_150(clk_150mhz_int), // 150mhz
    //     .CLK_OUT_150_CE(osc_150_en), // 150mhz enable

    //     .CLK_OUT_300(clk_300mhz_int), // 300mhz
    //     .CLK_OUT_300_CE(osc_300_en), // 300mhz enable

    //     .RESET(~M_RESET_B),
    //     .LOCKED(pll_locked)
    // );

    (* S = "TRUE"*) pll_12_55_120_240_360_ce my_pll (
        .CLK_IN1(M_CLK_OSC),
        .CLK_OUT_12(clk_12mhz_int), // 12mhz

        .CLK_OUT_55_386(clk_55_386mhz_int), // 4mhz
        .CLK_OUT_55_386_CE(osc_55_386m_en), // 4mhz enable

        .CLK_OUT_120(clk_120mhz_int), // 30mhz
        .CLK_OUT_120_CE(osc_120m_en), // 30mhz enable

        .CLK_OUT_240(clk_240mhz_int), // 75mhz
        .CLK_OUT_240_CE(osc_240m_en), // 75mhz enable

        .CLK_OUT_360(clk_360mhz_int), // 150mhz
        .CLK_OUT_360_CE(osc_360m_en), // 150mhz enable

        .RESET(~M_RESET_B),
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

    // Oscillator enable logic
    // Enable the oscillator based on UART input
    always @(posedge clk_12mhz_int or negedge M_RESET_B) begin
        if (!M_RESET_B) begin
        // Default to disable
            // osc_4_en <= 1'b0; 
            // osc_30_en <= 1'b0; 
            // osc_75_en <= 1'b0; 
            // osc_150_en <= 1'b0;
            // osc_300_en <= 1'b0;
            osc_12khz_en <= 1'b0;
            osc_120khz_en <= 1'b0;
            osc_50khz_en <= 1'b0; 
            osc_55_386m_en <= 1'b0;
            osc_120m_en <= 1'b0;
            osc_240m_en <= 1'b0; 
            osc_360m_en <= 1'b0; 
            osc_12m_en <= 1'b0; 

        end else if (uart_data_valid) begin
        // Default to disable
            // osc_4_en <= 1'b0; 
            // osc_30_en <= 1'b0; 
            // osc_75_en <= 1'b0; 
            // osc_150_en <= 1'b0;
            // osc_300_en <= 1'b0;
            osc_12khz_en    <= 1'b0;
            osc_120khz_en   <= 1'b0;
            osc_50khz_en    <= 1'b0; 
            osc_12m_en      <= 1'b0; 
            osc_55_386m_en  <= 1'b0;
            osc_120m_en     <= 1'b0;
            osc_240m_en     <= 1'b0; 
            osc_360m_en     <= 1'b0; 

            if (uart_data_bus[15:8] == 8'hFF) begin
                case (uart_data_bus[7:0])
                    // 8'h02: osc_4_en   <= 1'b1;  // Enable 4MHz
                    // 8'h03: osc_30_en  <= 1'b1; // Enable 30MHz
                    // 8'h04: osc_75_en  <= 1'b1; // Enable 75MHz
                    // 8'h05: osc_150_en <= 1'b1;  // Enable 150MHz
                    // 8'h06: osc_300_en <= 1'b1;  // Enable 300MHz
                    8'h00: osc_12khz_en   <= 1'b1; // Enable 12kHz clock
                    8'h01: osc_50khz_en  <= 1'b1; // Enable 120kHz clock
                    8'h02: osc_120khz_en   <= 1'b1; // Enable 50kHz clock
                    8'h03: osc_12m_en     <= 1'b1;  // Enable 12MHz
                    8'h04: osc_55_386m_en <= 1'b1; // Enable 55.386MHz
                    8'h05: osc_120m_en    <= 1'b1;  // Enable 120MHz
                    8'h06: osc_240m_en    <= 1'b1;  // Enable 240MHz
                    8'h07: osc_360m_en    <= 1'b1;  // Enable 360MHz
                endcase
            end
        end
    end

    // clk divider for 12khz and 120khz outputs
    always @(posedge clk_12mhz_int or negedge M_RESET_B) begin
        if (!M_RESET_B) begin
            clk_120khz_int  <= 1'b0;
            clk_12khz_int   <= 1'b0;
            counter_120khz  <= 16'd0;
            counter_12khz   <= 16'd0;
            counter_50khz   <= 16'd0;
        end else begin
            // 120khz clock output
            if (osc_120khz_en) begin
                if (counter_120khz < 16'd49) begin
                    counter_120khz <= counter_120khz + 1;
                end else begin
                    counter_120khz <= 16'd0;
                    clk_120khz_int <= ~clk_120khz_int; // Toggle every 50 counts for 100 counts cycle (12MHz / 100 = 120kHz)
                end
            end
            else begin
                counter_120khz <= 16'd0; // Reset counter if not enabled
                clk_120khz_int <= 1'b0; // Ensure clock is low if not enabled
            end

            // 50khz clock output
            if (osc_50khz_en) begin
                if (counter_50khz < 16'd119) begin
                    counter_50khz <= counter_50khz + 1;
                end else begin
                    counter_50khz <= 16'd0;
                    clk_50khz_int <= ~clk_50khz_int; // Toggle every 120 counts for 240 counts cycle (12MHz / 240 = 50kHz)
                end
            end else begin
                counter_50khz <= 16'd0; // Reset counter if not enabled
                clk_50khz_int <= 1'b0; // Ensure clock is low if not enabled
            end

            // 12khz clock output
            if (osc_12khz_en) begin
                if (counter_12khz < 16'd499) begin
                    counter_12khz <= counter_12khz + 1;
                end else begin
                    counter_12khz <= 16'd0;
                    clk_12khz_int <= ~clk_12khz_int; // Toggle every 500 counts for 1000 counts cycle (12MHz / 1000 = 12kHz)
                end
            end else begin
                counter_12khz <= 16'd0; // Reset counter if not enabled
                clk_12khz_int <= 1'b0; // Ensure clock is low if not enabled
            end
        end 
    end 

    // Assign output to header
    // assign M_HEADER = wave_out_lut;
    assign M_HEADER = 1'b0;
    // assign M_LED_0 = osc_4_en || osc_30_en || osc_75_en || osc_150_en || osc_300_en; // LED to indicate any oscillator is enabled
    assign M_LED_0 = osc_12khz_en || osc_50khz_en || osc_120khz_en || osc_12m_en || osc_55_386m_en || osc_120m_en || osc_240m_en || osc_360m_en; // LED to indicate any oscillator is enabled
    assign M_LED_1 = pll_locked;
    assign M_LED_2 = M_RESET_B;
    
    dipole_quad_full dipole_quad_full_inst (
        .antenna_in(clk_12khz_int ||clk_50khz_int || clk_120khz_int || clk_12mhz_antenna_int || clk_55_386mhz_int || clk_120mhz_int || clk_240mhz_int) // clk_360mhz_int can replace clk_240mhz_int or any other clk. but they cannot all fit together.
    );

endmodule
