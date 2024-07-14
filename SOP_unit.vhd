library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;
use work.NNProject.all;

entity SOP_unit is
	generic(
		i_N : integer := 4;
		i_weights_column : integer := 3;
		i_weights_row : integer := 4);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_data, i_weights, i_bias: in std_logic;  
			o_SOP : out std_logic;
			o_valid : out std_logic;
			o_error_serialize_pulse : out std_logic); --32 bit output floating point
end SOP_unit;

architecture behavioral of SOP_unit is
	 
	signal r_SOP : std_logic;  
	
component Generic_fp_matrix_addition is
	generic(
		i_row : integer := 2;
		i_column : integer := 2;
		i_bits : integer := 32);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data :in std_logic;
			o_sum : out std_logic;
			o_valid : out std_logic;
			o_error_serialize_pulse : out std_logic);
end component;

component Generic_fp_matrix_multiplication is
	generic(
		i_A_row : integer := 2;
		i_A_column : integer := 2;
		i_B_row : integer := 2;
		i_B_column : integer := 2;
		i_bits : integer := 32);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data :in std_logic;
			o_product : out std_logic);
end component;

	begin
	
	SOP0 :  Generic_fp_matrix_multiplication
	generic map(
		i_A_row => 1,
		i_A_column => i_N,
		i_B_row => i_weights_row,
		i_B_column => i_weights_column,
		i_bits =>32)
	port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_A_data => i_data,
			i_B_data => i_weights,
			o_product => r_SOP);
			
	SOP1 : Generic_fp_matrix_addition
	generic map(
		i_row => 1,
		i_column => i_weights_column,
		i_bits=> 32)
	port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_A_data => r_SOP, 
			i_B_data => i_bias,
			o_sum => o_SOP,
			o_valid => o_valid,
			o_error_serialize_pulse => o_error_serialize_pulse);
	
end architecture;



