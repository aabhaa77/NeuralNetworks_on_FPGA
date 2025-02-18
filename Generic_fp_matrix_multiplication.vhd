library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity Generic_fp_matrix_multiplication is
	--when we use this in a test bench, you could alter the generic
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
			o_product : out std_logic;
			o_valid : out std_logic;
			o_error_serialize_pulse : out std_logic);
end Generic_fp_matrix_multiplication;

architecture behavioral of Generic_fp_matrix_multiplication is
		
	type A_matrixType is array(0 to i_A_row-1, 0 to i_A_column-1) of std_logic_vector(i_bits-1 downto 0);
	signal r_matA : A_matrixType;
	type B_matrixType is array(0 to i_B_row-1, 0 to i_B_column-1) of std_logic_vector(i_bits-1 downto 0);
	signal r_matB : B_matrixType;
	signal i1, j1: integer :=0;
	signal i2, j2: integer :=0;
	signal i3, j3, k3: integer :=0;
	signal i4, j4: integer := 0;
	--signal w_multiplication: std_logic;
	type outType is array(0 to i_A_row-1, 0 to i_B_column-1) of std_logic_vector(i_bits-1 downto 0);
	signal r_matC : outType ;
	
	--intermediate signal
	signal r_A : std_logic_vector((i_A_row * i_A_column * i_bits)-1 downto 0);
	signal r_B : std_logic_vector((i_B_row * i_B_column * i_bits)-1 downto 0);
	signal r_A_data_valid : std_logic;
	signal r_B_data_valid : std_logic; 
	
	signal product_temp : std_logic_vector(i_bits-1 downto 0) := (others => '0');

	signal r_output_product: std_logic_vector((i_B_column*i_A_row*i_bits )-1 downto 0);
		
	--procedure for fp_addition - input is in vector format
	procedure addition_fp(signal A : in std_logic_vector(31 downto 0);
								signal B : in std_logic_vector(31 downto 0);                          
								signal sum : out   std_logic_vector(31 downto 0)) is
											
	variable r_A_mantissa, r_B_mantissa, r_sum_mantissa : std_logic_vector(23 downto 0); 
	variable r_A_exp, r_B_exp, r_sum_exp : std_logic_vector(8 downto 0); --factoring in carry over during addition
	variable r_A_sign, r_B_sign, r_sum_sign : std_logic;
	
	variable w_addition : std_logic;
	variable difference : signed(8 downto 0);
	
	begin
		w_addition := '0';
		
		r_A_sign := A(31);
		r_A_exp := '0' &  A(30 downto 23);
		r_A_mantissa := "0" &  A(22 downto 0);
					
		r_B_sign := B(31);
		r_B_exp := '0' & B(30 downto 23);
		r_B_mantissa := "0" & B(22 downto 0);
					
		--alignment of the numbers
		if unsigned(r_A_exp) > unsigned(r_B_exp) then
			difference := signed(r_A_exp) - signed(r_B_exp);
			if difference > 23 then
				--in case the difference is greater then during alignment the smaller number can be neglected
				r_sum_mantissa := r_A_mantissa;
				r_sum_exp := r_A_exp;
				r_sum_sign := r_A_sign;
				w_addition := '1';
			else
				--downshift of B
				r_sum_exp := r_A_exp;
				r_B_mantissa(23 downto (24 - to_integer(difference))) := (others => '0');
				r_B_mantissa((23 - to_integer(difference)) downto 0) := r_B_mantissa(23 downto to_integer(difference));

			end if;
		elsif unsigned(r_A_exp) < unsigned(r_B_exp) then
			difference := signed(r_B_exp) - signed(r_A_exp);
			if difference > 23 then
				r_sum_mantissa := r_B_mantissa;
				r_sum_exp := r_B_exp;
				r_sum_sign := r_B_sign;
				w_addition := '1';
			else
			--downshift of A
				r_sum_exp := r_B_exp;
				r_A_mantissa(23 downto (24 - to_integer(difference))) := (others => '0');
				r_A_mantissa((23 - to_integer(difference)) downto 0) := r_A_mantissa(23 downto to_integer(difference));
			
			end if;
		else
			r_sum_exp := r_A_exp;
	
		end if;
			
		--summation of the two numbers
		if w_addition = '0' then
			if(r_A_sign xor r_B_sign) = '0' then --both are of same sign
				r_sum_mantissa := std_logic_vector(unsigned(r_A_mantissa) + unsigned(r_B_mantissa));
				r_sum_sign := r_A_sign;
			elsif unsigned(r_A_mantissa) >= unsigned(r_B_mantissa) then
				r_sum_mantissa := std_logic_vector(unsigned(r_A_mantissa) - unsigned(r_B_mantissa));
				r_sum_sign := r_A_sign;
			else
				r_sum_mantissa := std_logic_vector(unsigned(r_B_mantissa) - unsigned(r_A_mantissa));
				r_sum_sign := r_B_sign;
			end if;
			
			--normalization of the summation
			if r_sum_mantissa(23) = '1' then --presence of acrry over, hence downshift
				r_sum_mantissa := '0' & r_sum_mantissa(23 downto 1);
				r_sum_exp := std_logic_vector(unsigned(r_sum_exp) + 1);
		
			end if;
		end if;
			
		--output formatting
		
		sum(22 downto 0) <= r_sum_mantissa(22 downto 0);
		sum(30 downto 23) <= r_sum_exp(7 downto 0);
		sum(31) <= r_sum_sign;
		     
	 end procedure;
	 
	 --procedure for fp_multiplication
	procedure multiplication_fp(signal A : in std_logic_vector(31 downto 0);
									 signal B : in std_logic_vector(31 downto 0);                          
									 signal Product : out   std_logic_vector(31 downto 0)) is
	
	variable r_A_mantissa : std_logic_vector(22 downto 0);
	variable r_A_exp : std_logic_vector(8 downto 0); --extra bit for overflow during addition
	variable r_A_sign : std_logic;
	
	variable r_B_mantissa : std_logic_vector(22 downto 0);
	variable r_B_exp : std_logic_vector(8 downto 0);
	variable r_B_sign : std_logic;
		
	variable r_multi_mantissa : std_logic_vector(22 downto 0);
	variable r_multi_exp : std_logic_vector(8 downto 0);
	variable r_multi_sign : std_logic;
	
	variable temp_product : std_logic_vector(45 downto 0);
	
	begin
		
		r_A_mantissa(22 downto 0) := A(22 downto 0);
		r_A_exp(7 downto 0) := A(30 downto 23);
		r_A_exp(8) := '0';
		r_A_sign := A(31);
		
		r_B_mantissa(22 downto 0) := B(22 downto 0);
		r_B_exp(7 downto 0) := B(30 downto 23);
		r_B_exp(8) := '0';
		r_B_sign := B(31);
		
		if (unsigned(r_A_exp) = 255 or unsigned(r_B_exp) = 255) then
		--Overflow condition, if either exp is 255, then the output goes to infinity
			r_multi_exp := "111111111"; --condition for NaN
			r_multi_mantissa := (others => '0');
			r_multi_sign := (r_A_sign xor r_B_sign);
		end if;
		
		if (unsigned(r_A_mantissa) = 0 or unsigned(r_B_mantissa) = 0) then 
		--condition to check zero
			r_multi_mantissa := (others => '0');
			r_multi_exp := std_logic_vector(unsigned(r_A_exp) + unsigned(r_B_exp));
			r_multi_Sign := (r_A_sign xor r_B_sign);
		
		else
			r_multi_sign := (r_A_sign xor r_B_sign);
			r_multi_exp := std_logic_vector(unsigned(r_A_exp) + unsigned(r_B_exp) - 127);
			temp_product := std_logic_vector(unsigned(r_A_mantissa) * unsigned(r_B_mantissa));
				
			--check underflow by keeping msb of mantissa as non zero - done by rigth shift and subtracting 1 from exp
			for i in 1 to 46 loop
				if (temp_product(45) = '0' and unsigned(r_multi_exp) > 0) then
					temp_product(45 downto 0) := temp_product(44 downto 0) & '0';
					r_multi_exp := std_logic_vector(unsigned(r_multi_exp) - 1);
				end if;
			end loop;
				
			--checking overflow in exp of multi
			if (unsigned(r_multi_exp) = 255 or r_multi_exp(8) = '1') then 
				r_multi_exp := "111111111";
				r_multi_mantissa := (others => '0');
				r_multi_sign := (r_A_sign xor r_B_sign);
			end if;
		
		end if;
		--rounding off condition : currently just truncating the right most digits
		Product(31) <= r_multi_sign;
		Product(30 downto 23) <= r_multi_exp(7 downto 0);
		Product(22 downto 0) <= temp_product(45 downto 23);	
				      
    end procedure;
	 
	
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

	begin
	
	SP0 : serial2parallel
	generic map(G_N => (i_A_row*i_A_column*i_bits))
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
	
	SP3: parallel2serial 
	generic map(G_N => (i_A_row * i_B_column * i_bits))
	port map(i_clk=> i_clk,
			i_rst => i_reset,
			--i_data_enable => '1',
			i_data => r_output_product,
			o_data_valid => o_valid,
			o_data => o_product,
			o_error_serialize_pulse => o_error_serialize_pulse);
	
	
	process (r_A_data_valid, r_B_data_valid)
	
	begin
	
	--w_multiplication <= '0';
	
	if (r_A_data_valid = '1' and r_B_data_valid = '1') then
	
		--converting vector to matrix
		for i1 in 0 to i_A_row-1 loop
			for j1 in 0 to i_A_column-1 loop
				r_matA(i1,j1) <= r_A(((i1*(i_A_column)+j1+1)*i_bits)-1 downto (i1*(i_A_column)+j1)*i_bits);
			end loop;
		end loop;
		
		for i2 in 0 to i_B_row-1 loop
			for j2 in 0 to i_B_column-1 loop
				r_matB(i2,j2) <= r_B(((i2*(i_B_column)+j2+1)*i_bits)-1 downto (i2*(i_B_column)+j2)*i_bits);
				--r_matB(i2,j2) <= r_B((((2*i2)+ j2 + 1)*i_bits)-1 downto (2*i2 + j2)*i_bits);
			end loop;
		end loop;
						
		--multiplication of 2D matrix
		for i3 in 0 to i_A_row-1 loop --matC_row
			for j3 in 0 to i_B_column-1 loop --matC_column
				for k3 in 0 to i_B_row-1 loop --either B_row ==A_column
				multiplication_fp(r_matA(i3,k3), r_matB(k3,j3), product_temp);	
				addition_fp(r_matC(i3,j3), product_temp, r_matC(i3,j3));
				end loop;
			end loop;
		end loop;
		
		--return in 1D matrix
		for i4 in 0 to i_A_row-1 loop --matC_row
			for j4 in 0 to i_B_column -1 loop --matC_column
				r_output_product(((i4*(i_B_column)+j4+1)*(i_bits)-1) downto (i4*(i_B_column)+j4)*(i_bits)) <= r_matC(i4,j4);
			end loop;
		end loop;
					
		end if;
		
	end process;
	
	

		
end architecture;



