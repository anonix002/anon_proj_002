module modulator (
    input clk,
    input reset,

    input [127:0] in_bitstream,
    input [15:0] symbol_time,      // Number of clock cycles per symbol
    input [3:0] repetition_factor, // Number of times to repeat the entire bitstream
    input start,

    output reg done,
    output reg wave_enable,
    output reg out
);

    // State machine
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam TRANSMIT = 3'b001;
    localparam SYMBOL_WAIT = 3'b010;
    localparam COMPLETE = 3'b011;

    // Counters and indices
    reg [15:0] symbol_counter;     // Counts clock cycles for current symbol
    reg [6:0] bit_counter;         // Counts number of bits transmitted (0-127)
    reg [127:0] bitstream_reg;     // Local copy of bitstream
    reg [15:0] symbol_time_reg;    // Local copy of symbol time
    reg [3:0] repetition_factor_reg; // Local copy of repetition factor
    reg [3:0] repeat_counter;   // Number of times to repeat the entire bitstream

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 1'b0;
            wave_enable <= 1'b0;
            out <= 1'b0;
            symbol_counter <= 32'd0;
            bit_counter <= 7'd0;
            repeat_counter <= 4'd0;
            repetition_factor_reg <= 4'd0;
            bitstream_reg <= 128'd0;
            symbol_time_reg <= 15'd0;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    wave_enable <= 1'b0;
                    out <= 1'b0;
                    symbol_counter <= 32'd0;
                    bit_counter <= 7'd0;
                    repeat_counter <= 4'd0;
                    
                    if (start) begin
                        bitstream_reg <= {in_bitstream[126:0], 1'b0}; // Shift left to prepare for transmission
                        symbol_time_reg <= symbol_time;
                        repetition_factor_reg <= repetition_factor;
                        state <= SYMBOL_WAIT;
                        wave_enable <= 1'b1;
                        out <= in_bitstream[127];  // MSB first
                        symbol_counter <= 32'd1;  // Start counting from 1
                    end
                end
                
                TRANSMIT: begin
                    // Set output based on current bit
                    out <= bitstream_reg[127];  // MSB first
                    bitstream_reg <= {bitstream_reg[126:0], 1'b0}; // Shift left
                    state <= SYMBOL_WAIT; // Move to wait state
                    symbol_counter <= 32'd1;  // Start counting from 1
                end
                
                SYMBOL_WAIT: begin
                    // Keep current output stable for symbol_time cycles
                    if (symbol_counter >= symbol_time_reg-1) begin
                        symbol_counter <= 32'd0;

                        if (repeat_counter >= (repetition_factor_reg - 1)) begin
                            repeat_counter <= 4'd0;
                            if (bit_counter >= 7'd127) begin
                                // All bits transmitted
                                state <= COMPLETE;
                            end
                            else begin
                                // Move to next bit
                                bit_counter <= bit_counter + 1'b1;
                                state <= TRANSMIT;
                            end

                        end
                        else 
                            // Repeat the same bit again
                            repeat_counter <= repeat_counter + 1'b1;
                    end
                    else begin
                        symbol_counter <= symbol_counter + 1'b1;
                    end
                end
                
                COMPLETE: begin
                    wave_enable <= 1'b0;
                    out <= 1'b0;
                    done <= 1'b1;
                    
                    // Wait for start to go low before returning to IDLE
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule