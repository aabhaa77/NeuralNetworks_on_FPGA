library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity activation_fn is --sgn function
	--when we use this in a test bench, we can alter the generic
	generic(
		i_row : integer := 1;
		i_column : integer := 1;
		i_bits: integer := 32);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_data : in std_logic;
			o_data : out std_logic_vector(i_column - 1 downto 0));
end activation_fn;

architecture behavioral of activation_fn is

	
	--intermediate matrix format
	type matrixType is array(0 to i_row - 1, 0 to i_column - 1) of std_logic_vector(i_bits - 1 downto 0);
	signal r_mat : matrixType;
	signal i, j: integer :=0;
	
	signal r_data : std_logic_vector((i_row * i_column * i_bits)-1 downto 0);
	signal r_data_valid : std_logic;
	
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
	
	begin
	
	SP0 : serial2parallel
	generic map(G_N => (i_row*i_column*i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_data,
				o_data_valid => r_data_valid,
				o_data => r_data);
	process(r_data_valid)
	begin	
	if (r_data_valid = '1') then
	
		for i in 0 to i_row-1 loop
			for j in 0 to i_column-1 loop
				r_mat(i,j) <= r_data(((i*(i_column-1)+j+1)*i_bits)-1 downto (i*(i_column-1)+j)*i_bits);
			end loop;
		end loop;
			
		for i in 0 to i_column - 1 loop
			if (r_mat(i, 0)(31) = '0') then
				o_data(i) <= '0';
			else
				o_data(i) <= '1';
			end if;
		end loop;
	end if;
	end process;
			
		
end architecture;



