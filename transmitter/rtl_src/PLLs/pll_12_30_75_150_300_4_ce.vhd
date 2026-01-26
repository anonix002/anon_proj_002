-- file: pll_12_30_75_150_300_4_ce.vhd
-- 
-- (c) Copyright 2008 - 2011 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
------------------------------------------------------------------------------
-- User entered comments
------------------------------------------------------------------------------
-- None
--
------------------------------------------------------------------------------
-- "Output    Output      Phase     Duty      Pk-to-Pk        Phase"
-- "Clock    Freq (MHz) (degrees) Cycle (%) Jitter (ps)  Error (ps)"
------------------------------------------------------------------------------
-- CLK_OUT1____12.000______0.000______50.0______469.975____232.343
-- CLK_OUT2____30.000______0.000______50.0______389.869____232.343
-- CLK_OUT3____75.001______0.000______50.0______316.912____232.343
-- CLK_OUT4___150.003______0.000______50.0______267.063____232.343
-- CLK_OUT5___300.005______0.000______50.0______234.347____232.343
-- CLK_OUT6_____4.688______0.000______50.0______561.271____232.343
--
------------------------------------------------------------------------------
-- "Input Clock   Freq (MHz)    Input Jitter (UI)"
------------------------------------------------------------------------------
-- __primary______________48____________0.010

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pll_12_30_75_150_300_4_ce is
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT_12          : out    std_logic;
  CLK_OUT_30_CE       : in     std_logic;
  CLK_OUT_30          : out    std_logic;
  CLK_OUT_75_CE       : in     std_logic;
  CLK_OUT_75          : out    std_logic;
  CLK_OUT_150_CE       : in     std_logic;
  CLK_OUT_150          : out    std_logic;
  CLK_OUT_300_CE       : in     std_logic;
  CLK_OUT_300          : out    std_logic;
  CLK_OUT_4_CE       : in     std_logic;
  CLK_OUT_4          : out    std_logic;
  -- Status and control signals
  RESET             : in     std_logic;
  LOCKED            : out    std_logic
 );
end pll_12_30_75_150_300_4_ce;

architecture xilinx of pll_12_30_75_150_300_4_ce is
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of xilinx : architecture is "pll_12_30_75_150_300_4_ce,clk_wiz_v3_6,{component_name=pll_12_30_75_150_300_4_ce,use_phase_alignment=false,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primtype_sel=PLL_BASE,num_out_clk=6,clkin1_period=20.833,clkin2_period=20.833,use_power_down=false,use_reset=true,use_locked=true,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=false,feedback_type=SINGLE,clock_mgr_type=AUTO,manual_override=false}";
  -- Input clock buffering / unused connectors
  signal clkin1      : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout         : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal clkout2          : std_logic;
  signal clkout3          : std_logic;
  signal clkout4          : std_logic;
  signal clkout5          : std_logic;
  -- Unused status signals

begin


  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => clkin1,
    I => CLK_IN1);


  -- Clocking primitive
  --------------------------------------
  -- Instantiation of the PLL primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused

  pll_base_inst : PLL_BASE
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "INTERNAL",
    DIVCLK_DIVIDE        => 2,
    CLKFBOUT_MULT        => 25,
    CLKFBOUT_PHASE       => 0.000,
    CLKOUT0_DIVIDE       => 50,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => 20,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => 8,
    CLKOUT2_PHASE        => 0.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => 4,
    CLKOUT3_PHASE        => 0.000,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => 2,
    CLKOUT4_PHASE        => 0.000,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => 128,
    CLKOUT5_PHASE        => 0.000,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => 20.833,
    REF_JITTER           => 0.010)
  port map
    -- Output clocks
   (CLKFBOUT            => clkfbout,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    CLKOUT2             => clkout2,
    CLKOUT3             => clkout3,
    CLKOUT4             => clkout4,
    CLKOUT5             => clkout5,
    -- Status and control signals
    LOCKED              => LOCKED,
    RST                 => RESET,
    -- Input clock control
    CLKFBIN             => clkfbout,
    CLKIN               => clkin1);

  -- Output buffering
  -------------------------------------


  clkout1_buf : BUFG
  port map
   (O   => CLK_OUT_12,
    I   => clkout0);



  clkout2_buf : BUFGCE
  port map
   (O   => CLK_OUT_30,
    CE  => CLK_OUT_30_CE,
    I   => clkout1);

  clkout3_buf : BUFGCE
  port map
   (O   => CLK_OUT_75,
    CE  => CLK_OUT_75_CE,
    I   => clkout2);

  clkout4_buf : BUFGCE
  port map
   (O   => CLK_OUT_150,
    CE  => CLK_OUT_150_CE,
    I   => clkout3);

  clkout5_buf : BUFGCE
  port map
   (O   => CLK_OUT_300,
    CE  => CLK_OUT_300_CE,
    I   => clkout4);

  clkout6_buf : BUFGCE
  port map
   (O   => CLK_OUT_4,
    CE  => CLK_OUT_4_CE,
    I   => clkout5);

end xilinx;
