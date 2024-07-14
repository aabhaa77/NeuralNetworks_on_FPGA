--library ieee;
--use ieee.std_logic_1164.all;
--
--entity test is
----code to test if p2s would convert s2p.
--
--	generic(G_N: integer := 32);
--	port (i_clk: in std_logic;
--			i_rst: in std_logic;
--			--i_data_enable: in std_logic;
--			i_data: in  std_logic_vector(G_N - 1 downto 0);
--			o_data_valid: out std_logic;
--			o_data: out std_logic_vector(G_N - 1 downto 0);
--			o_error_serialize_pulse: out std_logic);
--	end test;
--	
--	
--architecture rtl of test is
--	
--	--fsm approach
--	type state_type is (s2p, p2s);
--	signal state: state_type := p2s;
--
--	signal r_data_enable : std_logic;
--	signal r_data : std_logic_vector(G_N-1 downto 0);
--	signal r_count : integer range 0 to G_N -1;
--	signal r_converted_data : std_logic;
--	signal r_data_valid : std_logic;
--	
--	
--	component parallel2serial is
--	generic(G_N: integer := 32);
--	port (i_clk: in std_logic;
--			i_rst: in std_logic;
--			--i_data_enable: in std_logic;
--			i_data: in  std_logic_vector(G_N - 1 downto 0);
--			o_data_valid: out std_logic;
--			o_data: out std_logic;
--			o_error_serialize_pulse: out std_logic);
--	end component;
--	
--	component Serial2parallel is
--	generic( G_N : integer:=32); --generalized to be used for 32 bit floating points
--	port(
--		i_clk : in std_logic;
--		i_reset : in std_logic;
--		i_data_enable : in std_logic;
--		i_data : in std_logic;
--		o_data_valid : out std_logic;
--		o_data : out std_logic_vector(G_N - 1 downto 0));
--	end component;
--	
--	begin
--	
--	conversion: process (i_clk)
--		begin
--		SP0: parallel2serial
--				generic map(G_N => 32)
--				port map(i_clk => i_clk,
--						i_rst => i_rst,
--						--i_data_enable: in std_logic;
--						i_data => i_data,
--						o_data_valid => r_data_valid,
--						o_data => r_converted_data,
--						o_error_serialize_pulse => o_error_serialize_pulse);
--						
--		--r_data_valid <= o_data_valid;
--		if (o_data_valid = '1') then
--			SP1: Serial2parallel 
--					generic map( G_N => 32) --generalized to be used for 32 bit floating points
--					port map(
--						i_clk => i_clk,
--						i_reset => i_rst,
--						i_data_enable => r_data_valid,
--						i_data => r_converted_data,
--						o_data_valid => o_data_valid,
--						o_data => o_data);
--		end if;
--	end process;
--	
--end rtl;
------___________________

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.ALL;

entity test is
--code to test if p2s would convert s2p.

	generic(G_N: integer := 32;
	 r_A_row :  integer := 2;
	 r_A_col : integer := 1;--B_row
			 r_i_bits : integer :=32;
			 r_B_col : integer := 1);
	
	port (
			signal i_clk : in std_logic;
			signal A : in std_logic_vector(r_A_row * r_A_col * r_i_bits - 1 downto 0);
			signal B : in std_logic_vector(r_A_col * r_B_col * r_i_bits - 1 downto 0); 
			signal bias : in std_logic_vector(r_A_row * r_B_col * r_i_bits - 1 downto 0);
			signal Product : out   std_logic_vector(r_A_row * r_B_col * r_i_bits - 1 downto 0));
	end test;
--	

architecture rtl of test is

	signal A_row:  integer := r_A_row;
	 signal A_col : integer := r_A_col;--B_row
	signal i_bits : integer := r_i_bits;
	signal B_col : integer := r_B_col;
	 
	 procedure fp_addition_parallel(variable A : in std_logic_vector(31 downto 0);
								variable B : in std_logic_vector(31 downto 0);                          
								variable sum : out   std_logic_vector(31 downto 0)) is
											
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
		
		sum(22 downto 0) := r_sum_mantissa(22 downto 0);
		sum(30 downto 23) := r_sum_exp(7 downto 0);
		sum(31) := r_sum_sign;
		     
	 end procedure;
	 
	  --procedure for fp_multiplication-------------------
	procedure fp_multiplication_parallel(variable A : in std_logic_vector(31 downto 0);
									 variable B : in std_logic_vector(31 downto 0);                          
									 variable Product : out   std_logic_vector(31 downto 0)) is
	
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
		Product(31) := r_multi_sign;
		Product(30 downto 23) := r_multi_exp(7 downto 0);
		Product(22 downto 0) := temp_product(45 downto 23);	
				      
    end procedure;
	 
	 procedure SOP_unit_parallel(signal A_row : in integer;
									 signal A_col : in integer;--B_row
									 signal i_bits : in integer;
									 signal B_col : in integer;
									 signal A : in std_logic_vector;
									 signal B : in std_logic_vector; 
									 signal bias : in std_logic_vector;
									 signal Product : out   std_logic_vector) is
									 
	Variable r_A : std_logic_vector((i_bits*A_row*A_col)-1 downto 0);
	Variable r_B : std_logic_vector((i_bits*A_col*B_col)-1 downto 0) := B;
	Variable r_out : std_logic_vector((i_bits*A_row*B_col)-1 downto 0);
	Variable r_bias : std_logic_vector((i_bits*A_row*B_col)-1 downto 0);
	variable product_temp : std_logic_vector((i_bits*A_row*B_col)-1 downto 0);
	
	type A_matrixType is array(0 to A_row-1, 0 to A_col-1) of std_logic_vector(i_bits-1 downto 0);
	variable r_matA : A_matrixType;
	type B_matrixType is array(0 to A_col-1, 0 to B_col-1) of std_logic_vector(i_bits-1 downto 0);
	variable r_matB : B_matrixType;
	type outType is array(0 to A_row-1, 0 to B_col-1) of std_logic_vector(i_bits-1 downto 0);
	variable r_matC,r_matBias, r_Sum: outType ;
	variable  i1, i2, i3, i4, i5, i6, i7, i8, i9, i10: integer := 0;
	variable  j1, j2, j3, j4, j5, j6: integer := 0;
	variable  k1: integer := 0;
		
	
	begin
	--mapping 
		for i1 in 0 to (i_bits*A_row*A_col)-1 loop
			r_A(i1) := A(i1);
		end loop;
	for i2 in 0 to (i_bits*A_col*B_col)-1 loop
				r_B(i2) := B(i2);
	end loop;
		for i3 in 0 to (i_bits*A_row*B_col)-1 loop
			r_bias(i3) := bias(i3);
		end loop;
		
	--converting vector to matrix
		for i4 in 0 to A_row-1 loop
			for j1 in 0 to A_col-1 loop
				r_matA(i4,j1) := r_A(((i4*(A_col)+j1+1)*i_bits)-1 downto (i4*(A_col)+j1)*i_bits);
			end loop;
		end loop;
		
		for i5 in 0 to A_col -1 loop
			for j2 in 0 to B_col -1 loop
				r_matB(i5,j2) := r_B(((i5*(B_col)+j2+1)*i_bits)-1 downto (i5*(B_col)+j2)*i_bits);
				--r_matB(i2,j2) <= r_B((((2*i2)+ j2 + 1)*i_bits)-1 downto (2*i2 + j2)*i_bits);
			end loop;
		end loop;
						
		--multiplication of 2D matrix
		for i6 in 0 to A_row-1 loop --matC_row
			for j3 in 0 to B_col-1 loop --matC_column
				for k1 in 0 to A_col-1 loop --either B_row ==A_column
				fp_multiplication_parallel(r_matA(i6,k1), r_matB(k1,j3), product_temp(((i6*(B_col)+ j3 +1)*i_bits)-1 downto (i6*(B_col)+j3)*i_bits));	
				fp_addition_parallel(r_matC(i6,j3), product_temp(((i6*(B_col)+j3+1)*i_bits)-1 downto (i6*(B_col)+j3)*i_bits), r_matC(i6,j3));
				end loop;
			end loop;
		end loop;
		
		--for bias matrix
		for i7 in 0 to A_row - 1 loop
			for j4 in 0 to B_col-1 loop
			--check if the below expression satisfiy a non sqaure matrix			
				r_matBias(i7,j4) := r_bias(((i7*B_col +j4+1)*i_bits)-1 downto (i7*B_col+j4)*i_bits);
			end loop;
		end loop;
		
		for i8 in 0 to A_row - 1 loop
			for j5 in 0 to B_col-1 loop				
				fp_addition_parallel(r_matC(i8,j5), r_matBias(i8,j5), r_sum(i8,j5));	
			end loop;
		end loop;
			
		--return in 1D matrix
		for i9 in 0 to A_row - 1 loop
			for j6 in 0 to B_col-1 loop
				r_out(((i9 * B_col + j6 + 1) * i_bits)-1 downto (i9 * B_col + j6) * i_bits) := r_sum(i9,j6);
			end loop;
		end loop;
				
		for i10 in 0 to (i_bits*A_row*B_col)-1 loop
			Product(i10) <= r_out(i10);
		end loop;		
				      
    end procedure;
	 
	 begin
	 
	 process(i_clk)
	 
	 begin
	 
	 SOP_unit_parallel(A_row, A_col, i_bits, B_col, A, B, bias, Product);
	 
	 end process;
	 
	 
end rtl;



