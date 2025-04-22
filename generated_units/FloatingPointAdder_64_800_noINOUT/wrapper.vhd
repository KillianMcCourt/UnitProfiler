-----------------------------------------------------------------------
-- FloatingPointAdder, version 0.0
-----------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity fadd_op is
Generic (
 INPUTS: integer := 2; 
 OUTPUTS: integer := 1; 
 DATA_SIZE_IN: integer := 32; --we default to single precision
 DATA_SIZE_OUT: integer := 32
);
port (
    -- inputs
    clk          : in std_logic;
    rst          : in std_logic;
     lhs          : in std_logic_vector(65 downto 0);
    lhs_valid    : in std_logic;
    rhs          : in std_logic_vector(65  downto 0);
    rhs_valid    : in std_logic;
    result_ready : in std_logic;
    -- outputs
     result       : out std_logic_vector(65  downto 0);
    result_valid : out std_logic;
    lhs_ready    : out std_logic;
    rhs_ready    : out std_logic
  );
end entity;

architecture arch of fadd_op is
    
    
    -- legacy comment : main_component went here in component based version

    signal join_valid : STD_LOGIC;

    signal buff_valid, oehb_valid, oehb_ready : STD_LOGIC;
    signal oehb_dataOut, oehb_datain : std_logic_vector(0 downto 0);

    --intermediate input signals for float conversion
    signal ip_lhs, ip_rhs : std_logic_vector(65 downto 0);

    --intermidiate output signal(s) for float conversion
    signal ip_result : std_logic_vector(65 downto 0);

    

    begin


          join_inputs : entity work.join(arch) generic map(2) 
    port map( 
      -- inputs 
      ins_valid(0) => lhs_valid,
      ins_valid(1) => rhs_valid,
      outs_ready   => oehb_ready,
      -- outputs 
      outs_valid   => join_valid, 
      ins_ready(0) => lhs_ready, 
      ins_ready(1) => rhs_ready
    );

        buff: entity work.delay_buffer(arch) generic map(58)
        port map(clk,
                rst,
                join_valid,
                oehb_ready,
                buff_valid);

        oehb: entity work.oehb_dataless(arch)
            port map(
            clk        => clk,
            rst        => rst,
            ins_valid  => buff_valid,
            outs_ready => result_ready,
            outs_valid => result_valid,
            ins_ready  => oehb_ready
            );

        -- No input conversion: direct assignment
       ip_lhs <= lhs;

        -- No input conversion: direct assignment
       ip_rhs <= rhs;

        

        -- No output conversion: direct assignment
       result <= ip_result;

        operator : entity work.FloatingPointAdder(arch)
        port map (
            clk   => clk,
            ce_1 => oehb_ready,
            ce_2 => oehb_ready,
            ce_3 => oehb_ready,
            ce_4 => oehb_ready,
            ce_5 => oehb_ready,
            ce_6 => oehb_ready,
            ce_7 => oehb_ready,
            ce_8 => oehb_ready,
            ce_9 => oehb_ready,
            ce_10 => oehb_ready,
            ce_11 => oehb_ready,
            ce_12 => oehb_ready,
            ce_13 => oehb_ready,
            ce_14 => oehb_ready,
            ce_15 => oehb_ready,
            ce_16 => oehb_ready,
            ce_17 => oehb_ready,
            ce_18 => oehb_ready,
            ce_19 => oehb_ready,
            ce_20 => oehb_ready,
            ce_21 => oehb_ready,
            ce_22 => oehb_ready,
            ce_23 => oehb_ready,
            ce_24 => oehb_ready,
            ce_25 => oehb_ready,
            ce_26 => oehb_ready,
            ce_27 => oehb_ready,
            ce_28 => oehb_ready,
            ce_29 => oehb_ready,
            ce_30 => oehb_ready,
            ce_31 => oehb_ready,
            ce_32 => oehb_ready,
            ce_33 => oehb_ready,
            ce_34 => oehb_ready,
            ce_35 => oehb_ready,
            ce_36 => oehb_ready,
            ce_37 => oehb_ready,
            ce_38 => oehb_ready,
            ce_39 => oehb_ready,
            ce_40 => oehb_ready,
            ce_41 => oehb_ready,
            ce_42 => oehb_ready,
            ce_43 => oehb_ready,
            ce_44 => oehb_ready,
            ce_45 => oehb_ready,
            ce_46 => oehb_ready,
            ce_47 => oehb_ready,
            ce_48 => oehb_ready,
            ce_49 => oehb_ready,
            ce_50 => oehb_ready,
            ce_51 => oehb_ready,
            ce_52 => oehb_ready,
            ce_53 => oehb_ready,
            ce_54 => oehb_ready,
            ce_55 => oehb_ready,
            ce_56 => oehb_ready,
            ce_57 => oehb_ready,
            ce_58 => oehb_ready,
            ce_59 => oehb_ready,
            X     => ip_lhs,
            Y     => ip_rhs,
            R     => ip_result
        );
end architecture;



