module square_wave_generator (
    input wire clk,           // input clock
    input wire reset_n,       // Active low reset
    input wire enable,        // Enable signal
    input wire bypass,    // Bypass signal to output the original clock
    input wire [15:0] T,       // Period control input
    output square_out     // Single bit square wave output
);

    reg [15:0] counter;
    reg divided_clk;

    always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
            counter <= 15'd0;
            divided_clk <= 1'b0;
        end else begin
			if (enable && !bypass) begin
				if (counter >= T) begin
					counter <= 15'd0;
					divided_clk <= ~divided_clk;  // Toggle output
				end
				else begin
					counter <= counter + 1'b1;
				end
			end
            else begin
                counter <= 15'd0;  // Reset counter if not enabled
                divided_clk <= 1'b0;  // Ensure output is low when not enabled
            end
		end
    end

    assign square_out = (bypass && enable) ? clk : divided_clk;  // Bypass option to output the original clock  

endmodule
