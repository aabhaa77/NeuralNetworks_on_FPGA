library ieee;
use ieee.std_logic_1164.all;
use IEEE. numeric_std.all;

package  NNProject is

component DFFON is
	port( D : in std_logic;
			CLK : in std_logic;
			CLRN : in std_logic;
			PREN : in std_logic;
			Q : buffer std_logic;
			QN : buffer std_logic);	
end component;

component Serial2parallel is
	generic( G_N : integer:=32); 
	port(
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_data_enable : in std_logic;
		i_data : in std_logic;
		o_data_valid : out std_logic;
		o_data : out std_logic_vector(G_N - 1 downto 0));
end component;

component parallel2serial is
	generic(G_N: integer := 32);
	port (i_clk: in std_logic;
			i_rst: in std_logic;
			--i_data_enable: inout std_logic;
			i_data: in  std_logic_vector(G_N - 1 downto 0);
			o_data_valid: out std_logic;
			o_data: out std_logic;
			o_error_serialize_pulse: out std_logic);
end component;

component fp_addition is
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data : in std_logic; 
			o_sum : OUT std_logic_vector(31 downto 0));
end component;

component fp_multiplication is
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data : in std_logic;  
			o_product : out std_logic_vector(31 downto 0));
end component;

component Genric_Matrix_Addition is
	generic(
		i_row : integer := 2;
		i_column : integer := 2;
		i_bits : integer := 2);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data :in std_logic;
			o_sum : out std_logic_vector((i_row*i_column*(i_bits + 1)) - 1 downto 0));
end component;

component Genric_Matrix_Multiplication is
	generic(
		i_A_row : integer := 2;
		i_A_column : integer := 2;
		i_B_row : integer := 2;
		i_B_column :integer := 2;		
		i_bits : integer := 2);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data :in std_logic;
			o_multiplication : out std_logic_vector((i_A_column * i_B_row * (i_bits * 2))-1 downto 0)); --multiplication is A x B
end component;

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
			o_product : out std_logic_vector((i_B_column*i_A_row*i_bits )-1 downto 0));
end component;

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

end package;

