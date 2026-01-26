----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:30:25 04/20/2017 
-- Design Name: 
-- Module Name:    fsm_RX - Behavioral 
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
use IEEE.std_logic_arith.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fsm_RX is
	 Generic (bytes_to_receive : integer);
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           y : out  STD_LOGIC_VECTOR (bytes_to_receive*8 -1 downto 0);
           rx_inter : in  STD_LOGIC_VECTOR (7 downto 0);
           new_rx_data : in  STD_LOGIC;
           valid_out : out  STD_LOGIC);
end fsm_RX;

architecture Behavioral of fsm_RX is

-- COMPONENT
COMPONENT y_assign is
    Port ( y_in : in  STD_LOGIC_VECTOR (7 downto 0);
           y_out : out  STD_LOGIC_VECTOR (7 downto 0));
end COMPONENT y_assign;

-- TYPES
type state_type is (S0, S1, S2, S3);
type vector_array is array (integer range <>) of std_logic_vector (7 downto 0);

-- SIGNALS
signal state : state_type := S0;
signal nextstate : state_type;
signal address : integer := (bytes_to_receive - 1);
signal y_int : vector_array (bytes_to_receive-1 downto 0);
signal enable_cnt : std_logic;

begin

fsm_stat_reg : 
	process(clk,reset)
	begin
	if reset = '1' then
		state <= S0;
	elsif rising_edge(clk) then
		state <= nextstate;
	end if;
	end process;
	
fsm_CL1 :
	process (state,new_rx_data,address)
	begin
	case state is
		when S0 =>
			if new_rx_data = '1' then	
				nextstate <= S1;
			else
				nextstate <= S0;
			end if;
		when S1 =>
			if address = 0 then
				nextstate <= S2;
			else
				nextstate <= S0;
			end if;
		when S2 =>
			nextstate <= S3;
		when S3 =>
			nextstate <= S0;
		when others =>
			nextstate <= S0;
		end case;
	end process;
	
	
	fsm_CL2 :
		process (state)
		begin
		case state is
			when S0 =>
				valid_out <= '0';
				enable_cnt <= '0';
			when S1 =>
				valid_out <= '0';
				enable_cnt <= '1';
			when S2 =>
				valid_out <= '1';
				enable_cnt <= '0';
			when S3 =>
				valid_out <= '1';
				enable_cnt <= '0';
			when others =>
				valid_out <= '0';
				enable_cnt <= '0';
		end case;
		end process;
		
	mem_insn :
		process(clk,reset,enable_cnt)
		begin
			if reset = '1' then
				y_int <= (others => (others => '0'));
			elsif rising_edge(clk) then
				if enable_cnt = '1' then
					y_int(address) <= rx_inter;
				end if;
			end if;
		end process;
		
	address_insn :
		process(clk,reset,enable_cnt)
		begin
			if reset = '1' then
				address <= (bytes_to_receive - 1);
			elsif rising_edge(clk) then
				if enable_cnt = '1' then
					if address = 0 then
						address <= (bytes_to_receive - 1);
					else
						address <= address - 1;
					end if;
				end if;
			end if;
		end process;
		
y_assign_insn :
	for N in 0 to (bytes_to_receive - 1) generate
		y_X : y_assign
		Port map ( 
			  y_in => y_int(N),
           y_out => y(N*8+7 downto N*8)
			  );
		end generate;

end Behavioral;

