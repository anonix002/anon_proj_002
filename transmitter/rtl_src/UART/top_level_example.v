`timescale 1ns / 1ps

module sakura_g_SBOX_clock_test(M_CLK_OSC, M_RESET_B, M_HEADER, FTDI_BDBUS);

parameter bytes_to_transmit = 2;
parameter bytes_to_receive = 16;

   input M_CLK_OSC;
   input M_RESET_B;
   output [1:0] M_HEADER;
   inout [7:0] FTDI_BDBUS;
   wire clk_in0;//, clk_in0_int;
   wire [bytes_to_receive*8-1 : 0] input_data; // input_data = MSB[plaintext_for_random][reg5_reset][key][plaintext]LSB
   wire start_tx;
   wire finish_tx;
   wire valid_in;
   wire LOCKED;
   wire trigger;
   wire enable_core;
   wire res_cipher_core;
	wire M_RESET;

	
	assign FTDI_BDBUS[7:2] = 6'bZZZZZZ;
	//assign M_HEADER[2] = valid_in;
	
	
	//----------------------------------------------------------------------------
	//UART implementation
	//----------------------------------------------------------------------------
	assign M_RESET = ~M_RESET_B;
	wire  [bytes_to_transmit*8-1 : 0] ciphertext_out_transmit_latched;

	////------------------------------------------------------------
	uart_interface #(.bytes_to_receive(bytes_to_receive), .bytes_to_transmit(bytes_to_transmit)) U0 (
	.clk(clk_in0), 
	.reset(M_RESET), 
	.ser_in(FTDI_BDBUS[0]), 
	.ser_out(FTDI_BDBUS[1]), 
	.bus_SERDES(input_data), 
	.ciphertext(ciphertext_out_transmit_latched), 
	.valid_in(valid_in), 
	.start_tx(start_tx), 
	.txFinish(finish_tx), 
	.eot());
	
	//----------------------------------------------------------------------------
	//FSM CONTROLLER
	//----------------------------------------------------------------------------
	
		FSM_CTRL_FOR_SBOX  U1 (
	.clk(clk_in0), 
	.reset(M_RESET_B_internal), //M_RESET_B),
	.valid_in(valid_in),  
	.trigger(trigger), 
	.tx_start(start_tx), 
	.txFinish(finish_tx), 
	.reset_opcode(reset_opcode),
	.reset_uart(reset_uart),
	.reset_main(M_RESET_B), //.reset_main(M_RESET_B), 
	.reg5_reset(reg5_reset),
//	.reset_opcode_all(reset_opcode_all),
	.valid_out(valid_out),
	.start_comp(start_comp),
	.cnt2_val(cnt_val)
	);
	
endmodule
