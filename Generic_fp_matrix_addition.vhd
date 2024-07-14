library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity Generic_fp_matrix_addition is
	--when we use this in a test bench, we can alter the generic
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
end Generic_fp_matrix_addition;

architecture behavioral of Generic_fp_matrix_addition is

	--intermediate matrix format
	type matrixType is array(0 to i_row - 1, 0 to i_column - 1) of std_logic_vector(i_bits - 1 downto 0);
	signal r_matA, r_matB : matrixType;
	type outType is array(0 to i_row - 1, 0 to i_column - 1) of std_logic_vector(i_bits - 1 downto 0);
	signal r_matC : outType;
	signal i, j: integer :=0;
	
	--intermediate signal
	signal r_A, r_B : std_logic_vector((i_row * i_column * i_bits) - 1 downto 0);
	signal r_A_data_valid : std_logic; --using same output valid variable beacause they are synchrnous and work parallel
	signal r_B_data_valid : std_logic;
	signal r_sum : std_logic_vector((i_row * i_column * i_bits) - 1 downto 0);
		
	procedure addition_fp(signal A : in std_logic_vector(31 downto 0);
								 signal B : in std_logic_vector(31 downto 0);                          
								 signal sum : out   std_logic_vector(31 downto 0)) is
											
	variable A_mantissa, B_mantissa, sum_mantissa : std_logic_vector(23 downto 0); 
	variable A_exp, B_exp, sum_exp : std_logic_vector(8 downto 0); --factoring in carry over during addition
	variable A_sign, B_sign, sum_sign : std_logic;
	
	variable w_addition : std_logic;
	variable diff : signed(8 downto 0);
	
	begin
		w_addition := '0';
		
		A_sign := A(31);
		A_exp := '0' &  A(30 downto 23);
		A_mantissa := "0" &  A(22 downto 0);
					
		B_sign := B(31);
		B_exp := '0' & B(30 downto 23);
		B_mantissa := '0' & B(22 downto 0);
					
		--alignment of the numbers
		if unsigned(A_exp) > unsigned(B_exp) then
			diff := signed(A_exp) - signed(B_exp);
			if diff > 23 then
				--in case the diff is greater then during alignment the smaller number can be neglected
				sum_mantissa := A_mantissa;
				sum_exp := A_exp;
				sum_sign := A_sign;
				w_addition := '1';
			else
				--downshift of B
				sum_exp := A_exp;
				B_mantissa(23 downto (24 - to_integer(diff))) := (others => '0');
				B_mantissa((23 - to_integer(diff)) downto 0) := B_mantissa(23 downto to_integer(diff));

			end if;
		elsif unsigned(A_exp) < unsigned(B_exp) then
			diff := signed(B_exp) - signed(A_exp);
			if diff > 23 then
				sum_mantissa := B_mantissa;
				sum_exp := B_exp;
				sum_sign := B_sign;
				w_addition := '1';
			else
			--downshift of A
				sum_exp := B_exp;
				A_mantissa(23 downto (24 - to_integer(diff))) := (others => '0');
				A_mantissa((23 - to_integer(diff)) downto 0) := A_mantissa(23 downto to_integer(diff));
			
			end if;
		else
			sum_exp := A_exp;
	
		end if;
			
		--summation of the two numbers
		if w_addition = '0' then
			if(A_sign xor B_sign) = '0' then --both are of same sign
				sum_mantissa := std_logic_vector(unsigned(A_mantissa) + unsigned(B_mantissa));
				sum_sign := A_sign;
			elsif unsigned(A_mantissa) >= unsigned(B_mantissa) then
				sum_mantissa := std_logic_vector(unsigned(A_mantissa) - unsigned(B_mantissa));
				sum_sign := A_sign;
			else
				sum_mantissa := std_logic_vector(unsigned(B_mantissa) - unsigned(A_mantissa));
				sum_sign := B_sign;
			end if;
			
			--normalization of the summation
			if sum_mantissa(23) = '1' then --presence of acrry over, hence downshift
				sum_mantissa := '0' & sum_mantissa(23 downto 1);
				sum_exp := std_logic_vector(unsigned(sum_exp) + 1);
		
			end if;
		end if;
			
		--output formatting
		
		sum(22 downto 0) <= sum_mantissa(22 downto 0);
		sum(30 downto 23) <= sum_exp(7 downto 0);
		sum(31) <= sum_sign;
		
	end procedure;
 
	component Serial2parallel is
		generic( G_N : integer:=32); 
		port( i_clk : in std_logic;
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


	begin
	
	SP0 : serial2parallel
	generic map(G_N => (i_row * i_column * i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_A_data,
				o_data_valid => r_A_data_valid,
				o_data => r_A);
					
	SP1 : serial2parallel
	generic map(G_N => (i_row * i_column * i_bits))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_B_data,
				o_data_valid => r_B_data_valid,
				o_data => r_B);
				
	SP3: parallel2serial 
	generic map(G_N => (i_row * i_column * i_bits))
	port map(i_clk=> i_clk,
			i_rst => i_reset,
			i_data => r_sum,
			o_data_valid => o_valid,
			o_data => o_sum,
			o_error_serialize_pulse => o_error_serialize_pulse);
	
	process (r_A_data_valid, r_B_data_valid)
				
	begin
		if (r_A_data_valid = '1' and r_B_data_valid = '1') then

		for i in 0 to i_row - 1 loop
			for j in 0 to i_column-1 loop
			--check if the below expression satisfiy a non sqaure matrix			
				r_matA(i,j) <= r_A(((i*i_column +j+1)*i_bits)-1 downto (i*i_column+j)*i_bits);
				r_matB(i,j) <= r_B(((i*i_column +j+1)*i_bits)-1 downto (i*i_column+j)*i_bits);
			end loop;
		end loop;
		--addition of 2D matrix
		
		for i in 0 to i_row - 1 loop
			for j in 0 to i_column-1 loop				
				addition_fp(r_matA(i,j), r_matB(i,j), r_matC(i,j));	
			end loop;
		end loop;
			
		--return in 1D matrix
		for i in 0 to i_row - 1 loop
			for j in 0 to i_column-1 loop
				r_sum(((i * i_column + j + 1) * i_bits)-1 downto (i * i_column + j) * i_bits) <= r_matC(i,j);
			end loop;
		end loop;
		end if;
	end process;
	end architecture;



