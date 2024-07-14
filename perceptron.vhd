library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity perceptron is
	generic(
		i_N : integer := 4;
		i_weights_column1 : integer := 2;
		i_weights_column2 : integer := 2;
		i_weights_column3 : integer := 1);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_data, i_weights1, i_weights2, i_weights3: in std_logic;  
			i_bias1, i_bias2, i_bias3 : in std_logic;
			o_perceptron : out std_logic_vector(i_weights_column3 -1 downto 0)); 
end perceptron;

architecture rtl of perceptron is

	signal o_layer1 : std_logic;
	signal o_layer2 : std_logic;
	signal r_SOP : std_logic;
	
	
	component SOP_unit is
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
			o_error_serialize_pulse : out std_logic);
	end component;
	
	component activation_fn is
	generic(
		i_row : integer := 1;
		i_column : integer := 1;
		i_bits: integer := 32);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_data : in std_logic;
			o_data : out std_logic_vector(i_column - 1 downto 0));
	end component;
	
	begin
	
	layer1 : SOP_unit
	generic map(
		i_N => i_N,
		i_weights_column => i_weights_column1,
		i_weights_row => i_N)
	port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_data => i_data,
			i_weights => i_weights1,
			i_bias => i_bias1,
			o_SOP => o_layer1); 
			
	layer2 : SOP_unit
	generic map(
		i_N => i_N,
		i_weights_column => i_weights_column2,
		i_weights_row => i_weights_column1)
	port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_data=> o_layer1,
			i_weights =>  i_weights2,
			i_bias => i_bias2,
			o_SOP => o_layer2); 
			
	layer3 : SOP_unit
	generic map(
		i_N => i_N,
		i_weights_column => i_weights_column3,
		i_weights_row => i_weights_column2)
	port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_data=> o_layer2,
			i_weights =>  i_weights3,
			i_bias => i_bias3,
			o_SOP => r_SOP);
			
	activation_function : activation_fn
	generic map(
		i_row => 1,
		i_column => i_weights_column3,
		i_bits => 32)
	port map( i_clk => i_clk,
			i_reset  => i_reset,
			i_data_enable => i_data_enable,
			i_data => r_SOP,
			o_data => o_perceptron);

end rtl;
