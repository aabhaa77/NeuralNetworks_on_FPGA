library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity Genric_Matrix_Multiplication is
	--when we use this in a test bench, we can alter the generic
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
end Genric_Matrix_Multiplication;

architecture behavioral of Genric_Matrix_Multiplication is

	--intermediate matrix format
	type A_matrixType is array(0 to i_A_row - 1, 0 to i_A_column - 1) of std_logic_vector(i_bits - 1 downto 0);
	signal r_matA : A_matrixType;
	type B_matrixType is array(0 to i_B_row - 1, 0 to i_B_column - 1) of std_logic_vector(i_bits - 1 downto 0);
	signal r_matB : B_matrixType;
	signal i, j, k: integer :=0;
	type outType is array(0 to i_A_column - 1, 0 to i_B_row - 1) of std_logic_vector((i_bits * 2) - 1 downto 0);
	signal r_matC : outType ;
	
	--intermediate signals converted to parallel
	signal r_A : std_logic_vector((i_A_row * i_A_column * i_bits) - 1 downto 0);
	signal r_B : std_logic_vector((i_B_row * i_B_column * i_bits) - 1 downto 0);
	
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
	generic map(G_N => (i_A_row * i_A_column * i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_A_data,
				o_data_valid => r_A_data_valid,
				o_data => r_A);
				
	SP1 : serial2parallel
	generic map(G_N => (i_B_row * i_B_column * i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_B_data,
				o_data_valid => r_B_data_valid,
				o_data => r_B);
	
	process (i_clk, r_A_data_valid, r_B_data_valid)
	
	begin

		for i in 0 to i_A_row-1 loop
			for j in 0 to i_A_column-1 loop
				r_matA(i,j) <= r_A(((i * i_A_column + j + 1) * i_bits)-1 downto (i * i_A_column + j) * i_bits);
			end loop;
		end loop;

		for i in 0 to i_B_row-1 loop
			for j in 0 to i_B_column-1 loop
				r_matB(i,j) <= r_B(((i * i_B_column + j + 1)*i_bits)-1 downto (i * i_B_column + j)*i_bits);
			end loop;
		end loop;
						
		--multiplication of 2D matrix
		for i in 0 to i_A_row-1 loop --matC_row
			for j in 0 to i_B_column-1 loop --matC_column
				for k in 0 to i_B_row-1 loop --either i_B_row == i_A_column
				r_matC(i, j) <= std_logic_vector(unsigned(r_matC(i, j)) + (unsigned(r_matA(i, k)) * unsigned(r_matB(k, j))));
				end loop;
			end loop;
		end loop;
		
		--return in 1D matrix
		for i in 0 to i_A_row - 1 loop --matC_row
			for j in 0 to i_B_column - 1 loop --matC_column
				o_multiplication(((i * i_B_column + j + 1) * (i_bits * 2) - 1) downto (i * i_B_column + j) * (i_bits * 2)) <= r_matC(i,j);
			end loop;
		end loop;
					
	end process;
	
end architecture;



