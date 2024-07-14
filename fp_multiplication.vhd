library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;
use work.NNProject.all;

entity fp_multiplication is
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data : in std_logic;  --32 bit output floating point
			o_product : out std_logic_vector(31 downto 0)); --32 bit output floating point
end fp_multiplication;

architecture behavioral of fp_multiplication is
	
	--note the input exponent of the floating point has to be added with the bias!
	
	--intermediate signal for A & B & ouput_sum
	signal r_A, r_B : std_logic_vector(31 downto 0);
	signal r_A_mantissa : std_logic_vector(22 downto 0);
	signal r_A_exp : std_logic_vector(8 downto 0); --extra bit for overflow during addition
	signal r_A_sign : std_logic;
	
	signal r_B_mantissa : std_logic_vector(22 downto 0);
	signal r_B_exp : std_logic_vector(8 downto 0);
	signal r_B_sign : std_logic;
		
	signal r_multi_mantissa : std_logic_vector(22 downto 0);
	signal r_multi_exp : std_logic_vector(8 downto 0);
	signal r_multi_sign : std_logic;
	
	signal r_A_data_valid : std_logic; 
	signal r_B_data_valid : std_logic; 
	
	begin
	
	SP0 : serial2parallel port map(i_clk, i_reset, i_data_enable, i_A_data, r_A_data_valid, r_A);
	SP1 : serial2parallel port map(i_clk, i_reset, i_data_enable, i_B_data, r_B_data_valid, r_B);
	
	process(i_clk, r_A_data_valid, r_B_data_valid)
	
	variable r_product_temp : std_logic_vector(45 downto 0);
	
	begin
		
		if (r_A_data_valid = '1' and r_B_data_valid = '1') then
		
		r_A_mantissa(22 downto 0) <= r_A(22 downto 0);
		r_A_exp(7 downto 0) <= r_A(30 downto 23);
		r_A_exp(8) <= '0';
		r_A_sign <= r_A(31);
		
		r_B_mantissa(22 downto 0) <= r_B(22 downto 0);
		r_B_exp(7 downto 0) <= r_B(30 downto 23);
		r_B_exp(8) <= '0';
		r_B_sign <= r_B(31);
		
		if (unsigned(r_A_exp) = 255 or unsigned(r_B_exp) = 255) then
		--Overflow condition, if either exp is 255, then the output goes to infinity
			r_multi_exp <= "111111111"; --condition for NaN
			r_multi_mantissa <= (others => '0');
			r_multi_sign <= (r_A_sign xor r_B_sign);
		end if;
		
		if (unsigned(r_A_mantissa) = 0 or unsigned(r_B_mantissa) = 0) then 
		--condition to check zero
			r_multi_mantissa <= (others => '0');
			r_multi_exp <= std_logic_vector(unsigned(r_A_exp) + unsigned(r_B_exp));
			r_multi_Sign <= (r_A_sign xor r_B_sign);
		
		else
			r_multi_sign <= (r_A_sign xor r_B_sign);
			r_multi_exp <= std_logic_vector(unsigned(r_A_exp) + unsigned(r_B_exp) - 127);
			r_product_temp := std_logic_vector(unsigned(r_A_mantissa) * unsigned(r_B_mantissa));
				
			--check underflow by keeping msb of mantissa as non zero - done by rigth shift and subtracting 1 from exp
			for i in 1 to 46 loop
				if (r_product_temp(45) = '0' and unsigned(r_multi_exp) > 0) then
					r_product_temp(45 downto 0) := r_product_temp(44 downto 0) & '0';
					r_multi_exp <= std_logic_vector(unsigned(r_multi_exp) - 1);
				end if;
			end loop;
				
			--checking overflow in exp of multi
			if (unsigned(r_multi_exp) = 255 or r_multi_exp(8) = '1') then 
				r_multi_exp <= "111111111";
				r_multi_mantissa <= (others => '0');
				r_multi_sign <= (r_A_sign xor r_B_sign);
			end if;
		
		end if;
		--rounding off condition : truncating the right most digits
		o_product(31) <= r_multi_sign;
		o_product(30 downto 23) <= r_multi_exp(7 downto 0);
		o_product(22 downto 0) <= r_product_temp(45 downto 23);	
		
		end if;
	
		end process;
	
end architecture;



