----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:03:19 04/20/2017 
-- Design Name: 
-- Module Name:    fsm_TX - Behavioral 
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

entity fsm_TX is
	 Generic ( bytes_to_transmit : integer := 8);
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           y : in  STD_LOGIC_VECTOR (bytes_to_transmit*8 - 1 downto 0);
           tx_inter : out  STD_LOGIC_VECTOR (7 downto 0);
           txBusy : in  STD_LOGIC;
           newTx : out  STD_LOGIC;
			  txFinish : out STD_LOGIC;
           data_ready : in  STD_LOGIC);
end fsm_TX;

architecture Behavioral of fsm_TX is

-- TYPES
type state_type is (S0,S1,S2,S3, S4);

-- SIGNAL
signal state : state_type := S0;
signal nextstate : state_type;
signal no_bytes : integer := bytes_to_transmit-1;
signal newTx_int : std_logic;
signal tx_inter_int: std_logic_vector (7 downto 0) := (others => '0');
begin

newTx <= newTx_int;
tx_inter <= tx_inter_int;

fsm_stat_reg :
	process (clk,reset)
	begin
		if reset = '1' then
			state <= S0;
		elsif rising_edge(clk) then
			state <= nextstate;
		end if;
	end process;
	
fsm_CL1 : process(state, data_ready,txBusy, no_bytes)
	begin
	case state is
		when S0 =>
			if data_ready = '1' then
				nextstate <= S1;
			else
				nextstate <= S0;
			end if;
		when S1 =>
			if txBusy = '1' then
				nextstate <= S1;
			else
				nextstate <= S2;
			end if;
		when S2 =>
			if no_bytes = 0 then
				nextstate <= S3;
			else
				nextstate <= S1;
			end if;
		when S3 =>
			nextstate <= S4;
		when S4 =>
			nextstate <= S0;
		when others =>
			nextstate <= S0;
		end case;
	end process;

fsm_CL2 :
	process (state, y, no_bytes)
	begin
		case state is
			when S0 =>
				newTx_int <= '0';
				tx_inter_int <= (others => '0');
				txFinish <= '0';
			when S1 =>
				newTx_int <= '1';
				tx_inter_int <= y((no_bytes)*8+7 downto ((no_bytes)*8));
				txFinish <= '0';
			when S2 =>
				newTx_int <= '1';
				tx_inter_int <= (others => '0');
				txFinish <= '0';
			when S3 =>
				newTx_int <= '1';
				tx_inter_int <= y((no_bytes)*8+7 downto ((no_bytes)*8));
				txFinish <= '0';
			when S4 =>
				newTx_int <= '0';
				tx_inter_int <= (others => '0');
				txFinish <= '1';
			when others =>
				newTx_int <= '0';
				tx_inter_int <= (others => '0');
				txFinish <= '1';
		end case;
	end process;

--no_bytes_cnt :
--	process (clk,reset,state)
--	begin
--		if reset = '1' then
--			no_bytes <= bytes_to_transmit-1;
--		elsif rising_edge(clk) then
--			if state = S2 then
--				no_bytes <= no_bytes - 1;
--			elsif state = S3 or state = S4 then
--				no_bytes <= bytes_to_transmit - 1;
--			end if;
--		end if;
--	end process;
	
no_bytes_cnt: --GPT fix for -1 index
  process (clk, reset, state)
  begin
    if reset = '1' then
      no_bytes <= bytes_to_transmit - 1;
    elsif rising_edge(clk) then
      if state = S2 then
        if no_bytes = 0 then
          no_bytes <= bytes_to_transmit - 1;
        else
          no_bytes <= no_bytes - 1;
        end if;
      elsif state = S3 or state = S4 then
        no_bytes <= bytes_to_transmit - 1;
      end if;
    end if;
  end process;


--	process(state)--,clk)
--	begin
--	--if rising_edge(clk) then
--		if state = S1 or state = S3 then
--			tx_inter_int <= y((no_bytes)*8+7 downto ((no_bytes)*8));
--		elsif state = S0 then
--			tx_inter_int <= (others => '0');
--		end if;
--	--end if;
--	end process;

end Behavioral;

