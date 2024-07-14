library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.ALL;
use work.NNProject.all;

entity training_unit is
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
			i_expected_output : std_logic_vector(i_weights_column3 -1 downto 0);
			o_weight : out std_logic_vector( (32*(i_weights_column2 * i_weights_column3)) -1 downto 0)); --no.of element in weight matrix * 32bits
end training_unit;

architecture behavioral of training_unit is
	
	--intermediate signal
	signal r_output_valid1 : std_logic;
	signal r_output_valid2 : std_logic;
	signal r_output_valid : std_logic;
	signal r_output_valid3 : std_logic;
	signal r_data : std_logic_vector((32* i_N) -1 downto 0);
	signal r_weights2 : std_logic_vector((32* i_weights_column1 * i_weights_column2) -1 downto 0);
	signal r_weights1 : std_logic_vector((32* i_N * i_weights_column1) -1 downto 0);
	
	shared variable r_updating_weights : std_logic_vector((32* i_weights_column2 * i_weights_column3) -1 downto 0);
	shared variable r_bias1 : std_logic_vector((32*i_weights_column1) - 1 downto 0);
	shared variable r_bias2 : std_logic_vector((32*i_weights_column2) - 1 downto 0);
	shared variable r_bias3 : std_logic_vector((32*i_weights_column3) - 1 downto 0);
	signal new_weights3 : std_logic;
	signal obtained_output_initial : std_logic_vector(i_weights_column3 -1 downto 0);
	signal prev_loss : std_logic_vector(i_weights_column3 -1 downto 0);
	signal curr_loss : std_logic_vector(i_weights_column3 -1 downto 0);
	signal loss : std_logic_vector((i_weights_column3*32)-1 downto 0);
	signal threshold : std_logic_vector(31 downto 0);
	--variable slope : std_logic_vector((i_weights_column3*32)-1 downto 0);
	--variable learning_rate : bit_vector(31 downto 0);--LOOK INTO THIS
	
   --constant learning_rate : bit_vector(31 downto 0) := "00000000000000000000001111101000";
	signal obtained_output : std_logic_vector(i_weights_column3 -1 downto 0);
	signal one : integer := 1;
	signal r_N : integer := 4;
	signal  r_weights_column1 : integer := i_weights_column1;
	signal  r_weights_column2 : integer := i_weights_column2;
	signal  r_weights_column3 : integer := i_weights_column3;
	signal i_bits : integer := 32;
	
	shared variable temp : std_logic_vector(31 downto 0);
	signal i1, i2, i3, j1, i : integer := 0;
		
	--procedures
	--procedure for fp_addition_parallel ----------------------------
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

procedure SOP_unit_parallel(signal A_row : in integer;--if we hardcode it, 1
									 signal A_col : in integer;--B_row , 2
									 --signal i_bits : in integer;--, 32
									 signal B_col : in integer;--, 1
									 variable A : in std_logic_vector;
									 variable B : in std_logic_vector; 
									 variable bias : in std_logic_vector;
									 variable Product : out   std_logic_vector) is
									 
	Variable r_A : std_logic_vector((i_bits*A_row*A_col)-1 downto 0);
	Variable r_B : std_logic_vector((i_bits*A_col*B_col)-1 downto 0);
	Variable r_out : std_logic_vector((i_bits*A_row*B_col)-1 downto 0);
	Variable r_bias : std_logic_vector((i_bits*A_row*B_col)-1 downto 0);
	variable product_temp : std_logic_vector((i_bits)-1 downto 0);
	variable i_bits : integer := 32;
	
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
		for i2 in 0 to (i_bits*A_col*B_col)-1 loop --
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
				fp_multiplication_parallel(r_matA(i6,k1), r_matB(k1,j3), product_temp);	
				fp_addition_parallel(r_matC(i6,j3), product_temp, r_matC(i6,j3));
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
				
		for i10 in 0 to (i_bits*A_row*B_col) - 1 loop
			Product(i10) := r_out(i10);
		end loop;		
				      
    end procedure;

	 --procedure for parallel perceptron
	 procedure perceptron_parallel(signal i_N : in integer;
											signal i_weights_column1 : in integer;
											signal i_weights_column2 : in integer;
											signal i_weights_column3 : in integer;
											signal i_data : in std_logic_vector;
											signal i_weights1 : in std_logic_vector;
											signal i_weights2 : in std_logic_vector;
											variable i_weights3 : in std_logic_vector;
											variable i_bias1 : in std_logic_vector;
											variable i_bias2 : in std_logic_vector;
											variable i_bias3 : in std_logic_vector;
											signal o_perceptron : out std_logic_vector) is
											
											
		variable r_data : std_logic_vector((32*i_N)-1 downto 0);
		variable r_weights1 : std_logic_vector((i_N* i_weights_column1* 32) -1 downto 0);
		variable r_weights2 : std_logic_vector((i_weights_column1*i_weights_column2* 32) -1 downto 0);
		variable r_weights3 : std_logic_vector((i_weights_column2*i_weights_column3* 32) -1 downto 0);
		variable r_bias1 : std_logic_vector((32*i_weights_column1) - 1 downto 0);
		variable r_bias2 : std_logic_vector((32*i_weights_column2) - 1 downto 0);
		variable r_bias3 : std_logic_vector((32*i_weights_column3) - 1 downto 0);
		variable r_perceptron : std_logic_vector(i_weights_column3 -1 downto 0);								
		
		variable r_layer1: std_logic_vector((i_weights_column1*32) - 1 downto 0);
		variable r_layer2: std_logic_vector((i_weights_column2*32) - 1 downto 0);
		variable r_layer3: std_logic_vector((i_weights_column3*32) - 1 downto 0);
		
		type matrixType is array(0 to i_weights_column2 - 1, 0 to i_weights_column3 - 1) of std_logic_vector(31 downto 0);
	   variable r_matACT : matrixType;
		
		variable  i1, i2, i3, i4, i5, i6: integer := 0;
		variable  j1, w1, w2, w3: integer := 0;
											
	
	begin
	
	for i1 in 0 to ((32 * i_N) - 1) loop
		r_data(i1) := i_data(i1);
	end loop;
	
	for i2 in 0 to (i_N * i_weights_column1* 32) - 1 loop
		r_weights1(i2) := i_weights1(i2);
		--r_bias1(i2) := i_bias1(i2);
	end loop;
	
	for i3 in 0 to (i_weights_column1*i_weights_column2* 32) - 1 loop
		r_weights2(i3) := i_weights2(i3);
		--r_bias2(i3) := i_bias2(i3);
	end loop;
	
	for i4 in 0 to (i_weights_column2 * i_weights_column3* 32) - 1 loop
		r_weights3(i4) := i_weights3(i4);
		--r_bias3(i4) := i_bias3(i4);
	end loop;
	
	for w1 in 0 to (i_weights_column1* 32) - 1 loop
		r_bias1(w1) := i_bias1(w1);
	end loop;
	
	for w2 in 0 to (i_weights_column2 * 32) - 1 loop
		r_bias2(w2) := i_bias2(w2);
	end loop;
	
	for w3 in 0 to (i_weights_column3 * 32) - 1 loop
		r_bias3(w3) := i_bias3(w3);
	end loop;
	
	
	SOP_unit_parallel(one, i_N, i_weights_column1, r_data, r_weights1, r_bias1,r_layer1);
	SOP_unit_parallel(one, i_weights_column1, i_weights_column2, r_layer1, r_weights2, r_bias2,r_layer2);
	SOP_unit_parallel(one, i_weights_column2, i_weights_column3, r_layer2, r_weights3, r_bias3,r_layer3);
	
	
		for j1 in 0 to i_weights_column3-1 loop
			r_matACT(0, j1) := r_layer3(((j1+1)*32)-1 downto (j1)*32);
		end loop;
			
		--activation function
		for i5 in 0 to i_weights_column3 - 1 loop
			if (r_matACT(i5, 0)(31) = '0') then
				r_perceptron(i5) := '0';
			else
				r_perceptron(i5) := '1';
			end if;
		end loop;
		
		for i6 in 0 to i_weights_column3-1 loop
			o_perceptron(i6) <= r_perceptron(i6);
		end loop;
		     
	end procedure;
	
	--components
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
	 
	component perceptron is
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
	end component;
	
	begin
	
	--learning_rate := (others => '0');
   --learning_rate := "00000000000000000000001111101000";
	
	
	--slope     <= "00000000000000000000000000000001";
	threshold <= "00111010100000000000000000000001";
	
	--learning_rate(31):='1';
	
	
	--port map
	SP0 : serial2parallel
	generic map(G_N => (i_weights_column2 * i_weights_column3 * 32))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_weights3,
				o_data_valid => r_output_valid3,
				o_data => r_updating_weights);
				
	SP1 : serial2parallel
	generic map(G_N => (i_weights_column1 * i_weights_column2 * 32))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_weights2,
				o_data_valid => r_output_valid2,
				o_data => r_weights2);
				
	SP2 : serial2parallel
	generic map(G_N => (i_N * i_weights_column1 * 32))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_weights1,
				o_data_valid => r_output_valid1,
				o_data => r_weights1);
	
	SP3 : serial2parallel
	generic map(G_N => (i_N * 32))
	port map(i_clk => i_clk,
				i_reset => i_reset,
				i_data_enable => i_data_enable,
				i_data => i_data,
				o_data_valid => r_output_valid,
				o_data => r_data);
				
				
	P0: perceptron
		generic map(
			i_N  => 4,
			i_weights_column1 => 2,
			i_weights_column2 => 2,
			i_weights_column3 => 1)
		port map( i_clk => i_clk,
			i_reset => i_reset,
			i_data_enable => i_data_enable,
			i_data => i_data,
			i_weights1 => i_weights1,
			 i_weights2 => i_weights2,
			 i_weights3 => new_weights3,
			i_bias1 => i_bias1,
			i_bias2=> i_bias2,
			i_bias3 =>  i_bias3,
			o_perceptron => obtained_output_initial);
					
	
	--process
	process (i_clk, r_output_valid1)
	
		variable learning_rate : std_logic_vector(31 downto 0) := "00000000000000000000001111101000";
		variable slope     : std_logic_vector((i_weights_column3*32)-1 downto 0) := "00000000000000000000000000000001";
		
	begin
	
	--if, for while loops!
		--initial percpetron value used to calculate the first prev_loss
		for i1 in 0 to i_weights_column3 -1 loop
				prev_loss(i1) <= (i_expected_output(i1) xor obtained_output_initial(i1)) and (i_expected_output(i1) xor obtained_output_initial(i1));
		end loop;
		
		--actual training part
		for i2 in 0 to i_weights_column3 loop
			while slope > threshold loop
				
				--updating weights
				for j1 in 0 to i_weights_column2 - 1 loop 
					fp_addition_parallel(r_updating_weights((j1+1)*32 -1 downto j1*32) , learning_rate,r_updating_weights((j1+1)*32 -1 downto j1*32)  );
				end loop;
				
				perceptron_parallel(r_N, r_weights_column1,r_weights_column2,r_weights_column3,r_data,r_weights1, r_weights2, r_updating_weights, r_bias1,r_bias2 ,r_bias3,obtained_output);
				
				for i3 in 0 to i_weights_column3 -1 loop
					Curr_loss(i3) <= (i_expected_output(i3) xor obtained_output(i3)) and (i_expected_output(i3) xor obtained_output(i3));
					--loss(i3) <= ("00000000000000000000000000000000") or (curr_loss(i3) xor prev_loss(i3));
					loss(i3) <=  (curr_loss(i3) xor prev_loss(i3));
					temp(31) := loss(i3);
					temp := (others => '0');
					
					fp_multiplication_parallel(temp ,learning_rate, slope((32*(i3+1))-1 downto i3*32));
					Prev_loss(i3) <= curr_loss(i3);
				end loop;
				
			
			end loop;
		end loop;
		
	end process;
	
			
end architecture;

