----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:57:26 04/19/2017 
-- Design Name: 
-- Module Name:    y_asign - Behavioral 
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

entity y_assign is
    Port ( y_in : in  STD_LOGIC_VECTOR (7 downto 0);
           y_out : out  STD_LOGIC_VECTOR (7 downto 0));
end y_assign;

architecture Behavioral of y_assign is

begin

y_out  <= y_in;

end Behavioral;

