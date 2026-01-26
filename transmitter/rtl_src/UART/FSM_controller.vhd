Library IEEE;
Use ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;



Entity FSM_controller is
	port (
			clk : IN std_logic;
			reset : IN std_logic;
			valid_in : IN std_logic;
			enable_core : OUT std_logic;
			job_done : IN std_logic;
			tx_start : OUT std_logic;
			AES_iter : OUT std_logic;
			txFinish : IN std_logic;
			trigger : OUT std_logic;
			res_cipher_core : OUT std_logic
	);
end entity;

Architecture controller_beh of FSM_controller is
	
		type state_type is (init, S0pre, S0, S1, S2, S3, S4);
		signal state : state_type;
		signal nextstate : state_type;
		signal enable_cnt : std_logic;
		signal cnt : std_logic_vector (3 downto 0);
		
		begin
		
		
		-- processo assegnazione stat prossimo
		p1 : process (clk, reset)
			 begin
				if reset = '0' then
				   state <= init;
				elsif rising_edge(clk) then
				   state <= nextstate;
				end if;
			 end process;
		
		p2 : process (state, valid_in, job_done, txFinish, cnt)
			 begin
			 case state is
				when init =>
					if valid_in = '1' then
						nextstate <= S0pre;
					else
						nextstate <= init;
					end if;
				when S0pre =>
					if cnt = "1111" then
						nextstate <= S0;
					else
						nextstate <= S0pre;
					end if;
				when S0 =>
					if job_done = '1' then
						nextstate <= S1;
					else
						nextstate <= S0;
					end if;
				when S1 =>
					if cnt = "1111" then
						nextstate <= S2;
					else
						nextstate <= S1;
					end if;
				when S2 =>
					nextstate <= S3;
				when S3 =>
					if job_done = '1' then
						nextstate <= S4;
					else
						nextstate <= S3;
					end if;
				when S4 =>
					if txFinish = '1' then
						nextstate <= init;
					else
						nextstate <= S4;
					end if;
				when others =>
					nextstate <= init;
			end case;
			end process;
			
		p3 : process (state)
			 begin
				case state is
					when init =>					--wait for data
						tx_start <= '0';
						res_cipher_core <= '0';
						enable_core <= '0';
						enable_cnt <= '0';
						AES_iter <= '0';
						trigger <= '0';
					when S0pre =>					--generate the trigger and wait
						tx_start <= '0';
						res_cipher_core <= '0';
						enable_core <= '0';
						enable_cnt <= '1';
						AES_iter <= '0';
						trigger <= '1';
					when S0 =>						--1st AES
						tx_start <= '0';
						res_cipher_core <= '1';
						enable_core <= '1';
						enable_cnt <= '0';
						AES_iter <= '0';
						trigger <= '1';
					when S1 =>						--counter state
						tx_start <= '0';
						res_cipher_core <= '0';
						enable_core <= '0';
						enable_cnt <= '1';
						AES_iter <= '0';
						trigger <= '1';
					when S2 =>						--masking state
						tx_start <= '0';
						res_cipher_core <= '0';
						enable_core <= '0';
						enable_cnt <= '0';
						AES_iter <= '1';
						trigger <= '1';
					when S3 =>						--2nd AES
						tx_start <= '0';
						res_cipher_core <= '1';
						enable_core <= '1';
						enable_cnt <= '0';
						AES_iter <= '1';
						trigger <= '1';
					when S4 =>						--flush ciphertext out
						tx_start <= '1';
						res_cipher_core <= '1';
						enable_core <= '0';
						enable_cnt <= '0';
						AES_iter <= '1';
						trigger <= '1';
					when others =>
						tx_start <= '0';
						res_cipher_core <= '0';
						enable_core <= '0';
						enable_cnt <= '0';
						AES_iter <= '0';
						trigger <= '0';
				end case;
			end process;
	    
		 cnt_inst : process(clk, reset, enable_cnt)
			begin
				if reset = '0' then
					cnt <= (others => '0');
				elsif rising_edge(clk) then
					if enable_cnt = '1' then
						cnt <= cnt + 1;
					else
						cnt <= (others => '0');
					end if;
				end if;
			end process;
			
end architecture;