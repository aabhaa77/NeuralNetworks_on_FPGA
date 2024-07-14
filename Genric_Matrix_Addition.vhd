library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity Genric_Matrix_Addition is
	--when we use this in a test bench, you could alter the generic
	generic(
		i_row : integer := 2;
		i_column : integer := 2;
		i_bits : integer := 2);
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data :in std_logic;
			o_sum : out std_logic_vector((i_row*i_column*(i_bits + 1)) - 1 downto 0));
end Genric_Matrix_Addition;

architecture behavioral of Genric_Matrix_Addition is

	--intermediate matrix format
	type matrixType is array(0 to i_row-1, 0 to i_column-1) of std_logic_vector(i_bits-1 downto 0);
	signal r_matA, r_matB : matrixType;
	type outType is array(0 to i_row-1, 0 to i_column-1) of std_logic_vector(i_bits downto 0);
	signal r_matC : outType;
	signal i, j: integer :=0;
	
	--intermediate signal
	signal r_A, r_B : std_logic_vector((i_row*i_column*i_bits) - 1 downto 0);
	
	signal r_A_data_valid : std_logic; 
	signal r_B_data_valid : std_logic; 

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
				i_data => i_A_data,
				o_data_valid => r_A_data_valid,
				o_data => r_A);
				
	SP1 : serial2parallel
	generic map(G_N => (i_row*i_column*i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_B_data,
				o_data_valid => r_B_data_valid,
				o_data => r_B);
	
	
	process (i_clk, r_A_data_valid, r_B_data_valid)
			
		begin

		if (r_A_data_valid = '1' and r_B_data_valid = '1') then
		
		--conversion of 1D to 2D matrix
		for i in 0 to i_row-1 loop
			for j in 0 to i_column-1 loop		
				r_matA(i,j) <= r_A(((i*i_column+j+1)*i_bits)-1 downto (i*i_column+j)*i_bits);
				r_matB(i,j) <= r_B(((i*i_column+j+1)*i_bits)-1 downto (i*i_column+j)*i_bits);
			end loop;
		end loop;
		
		--addition of 2D matrix
		for i in 0 to i_row-1 loop
			for j in 0 to i_column-1 loop
				r_matC(i,j) <= std_logic_vector(unsigned('0' & r_matA(i,j)) + unsigned('0' & r_matB(i,j)));
			end loop;
		end loop;
			
		--return in 1D matrix
		for i in 0 to i_row-1 loop
			for j in 0 to i_column-1 loop
				o_sum(((i*i_column+j+1)*(i_bits+1))-1 downto (i*i_column+j)*(i_bits+1)) <= r_matC(i,j);
			end loop;
		end loop;
		
		end if;
			
	end process;
		
end architecture;



