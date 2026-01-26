----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:15:37 04/20/2017 
-- Design Name: 
-- Module Name:    uart_interface - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_interface is
	 Generic (
				bytes_to_receive : integer := 18;
				bytes_to_transmit : integer := 8
				);
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  ser_in : in std_logic;
			  ser_out : out std_logic;
           bus_SERDES : out  STD_LOGIC_VECTOR (bytes_to_receive*8 - 1 downto 0);
           ciphertext : in  STD_LOGIC_VECTOR (bytes_to_transmit*8 - 1 downto 0);
           valid_in : out  STD_LOGIC;
           start_tx : in  STD_LOGIC;
			  txFinish : out STD_LOGIC;
           eot : out  STD_LOGIC);
end uart_interface;

architecture Behavioral of uart_interface is

-- UART
component uartTop is
  port ( -- global signals
         clr       : in  std_logic;                     -- global reset input
         clk       : in  std_logic;                     -- global clock input
         -- uart serial signals
         serIn     : in  std_logic;                     -- serial data input
         serOut    : out std_logic;                     -- serial data output
         -- transmit and receive internal interface signals
         txData    : in  std_logic_vector(7 downto 0);  -- data byte to transmit
         newTxData : in  std_logic;                     -- asserted to indicate that there is a new data byte for transmission
         txBusy    : out std_logic;                     -- signs that transmitter is busy
         rxData    : out std_logic_vector(7 downto 0);  -- data byte received
         newRxData : out std_logic;                     -- signs that a new byte was received
         -- baud rate configuration register - see baudGen.vhd for details
         baudFreq  : in  std_logic_vector(11 downto 0); -- baud rate setting registers - see header description
         baudLimit : in  std_logic_vector(15 downto 0); -- baud rate setting registers - see header description
         baudClk   : out std_logic);                    -- 
end component uartTop;

-- fsmRX

component fsm_RX is
	 Generic (bytes_to_receive : integer := 18);
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           y : out  STD_LOGIC_VECTOR (bytes_to_receive*8 - 1 downto 0);
           rx_inter : in  STD_LOGIC_VECTOR (7 downto 0);
           new_rx_data : in  STD_LOGIC;
           valid_out : out  STD_LOGIC);
end component fsm_RX;

-- fsmTX
component fsm_TX is
	 Generic (bytes_to_transmit : integer := 8);
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           y : in  STD_LOGIC_VECTOR (bytes_to_transmit* 8 - 1downto 0);
           tx_inter : out  STD_LOGIC_VECTOR (7 downto 0);
           txBusy : in  STD_LOGIC;
           newTx : out  STD_LOGIC;
			  txFinish : out STD_LOGIC;
           data_ready : in  STD_LOGIC);
end component fsm_TX;

-- SIGNALS
signal rx_data : std_logic_vector (7 downto 0);
signal tx_data : std_logic_vector (7 downto 0);
signal write_byte : std_logic;
signal read_byte : std_logic;
signal eot_int : std_logic;

begin

eot <= eot_int;

-- this module has been changed to receive the baud rate dividing counter from registers.
-- the two registers should be calculated as follows:
-- first register:
--              baud_freq = 16*baud_rate / gcd(global_clock_freq, 16*baud_rate)
-- second register:
--              baud_limit = (global_clock_freq / gcd(global_clock_freq, 16*baud_rate)) - baud_freq 

u_insn : uartTop
  port map( 
			-- global signals
         clr       => reset,
         clk       => clk,
         -- uart serial signals
         serIn     => ser_in,
         serOut    => ser_out,
         -- transmit and receive internal interface signals
         txData    => tx_data,
         newTxData => write_byte,
         txBusy    => eot_int,                     -- signs that transmitter is busy
         rxData    => rx_data,
         newRxData => read_byte,
         -- baud rate configuration register - see baudGen.vhd for details
         --baudFreq  => "000001100000", --9600bps, 1MHz
         --baudLimit => "0000001000010001",
			--baudFreq => "001001000000", --57600bps, 1MHz
			--baudLimit => "0000000000110001",
			--baudFreq => "000011000000",  --57600, 3MHz
			--baudLimit => "0000000110110001",
			--baudFreq => "000010010000",	--57600, 4MHz
			--baudLimit => "0000000111100001",
			--baudFreq => "000100100000", --57600, 2MHz
			--baudLimit => "0000000101010001",
			baudFreq => "000000110000", --57600, 12MHz
			baudLimit => "0000001001000001",
			--baudFreq => "000001100000", --57600, 6MHz
			--baudLimit => "0000001000010001",
         baudClk   => open); 

fsm_RX_insn : fsm_RX
	generic map (bytes_to_receive => bytes_to_receive)
	port map (
				clk => clk,
				reset =>	reset,
				y => bus_SERDES,
				rx_inter =>	rx_data,
				new_rx_data =>	read_byte,
				valid_out => valid_in
				);
--				
fsm_TX_insn : fsm_TX
	generic map ( bytes_to_transmit => bytes_to_transmit)
	port map (
				clk => clk,
				reset => reset,
				y => ciphertext,
				tx_inter => tx_data,
				txBusy => eot_int,
				txFinish => txFinish,
				newTx => write_byte,
				data_ready => start_tx
				);

end Behavioral;

