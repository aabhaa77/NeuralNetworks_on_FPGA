library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;
use work.NNProject.all;

entity fp_addition is
	port( i_clk : in std_logic;
			i_reset : in std_logic;
			i_data_enable : in std_logic;
			i_A_data, i_B_data : in std_logic; --32 bit input floating point taken serially
			o_sum : OUT std_logic_vector(31 downto 0)); --32 bit output floating point given parallely
end fp_addition;

architecture behavioral of fp_addition is

	--intermediate parallel signals for A & B & ouput_sum
	signal r_A, r_B : std_logic_vector(31 downto 0);
	signal r_A_mantissa, r_B_mantissa, r_sum_mantissa : std_logic_vector(23 downto 0); 
	signal r_A_exp, r_B_exp, r_sum_exp : std_logic_vector(8 downto 0); --factoring in carry over during addition
	signal r_A_sign, r_B_sign, r_sum_sign : std_logic;
	
	signal w_addition : std_logic; 		--high means addition has taken place
	
	signal r_A_data_valid : std_logic; --using same output valid variable beacause they are synchronous and work parallel
	signal r_B_data_valid : std_logic; --using same output valid variable beacause they are synchronous and work parallel
		
	begin
	
	SP0 : serial2parallel port map(i_clk, i_reset, i_data_enable, i_A_data, r_A_data_valid, r_A);
	SP1 : serial2parallel port map(i_clk, i_reset, i_data_enable, i_B_data, r_B_data_valid, r_B);
	
	process(i_clk, r_A_data_valid, r_B_data_valid) is-- i think the clk should not be there because fp_add is when the number is changed and that happend when the r_data_valid changes?
	
	variable r_exp_difference : signed(8 downto 0);			
	
	begin
		w_addition <= '0';

		if (r_A_data_valid = '1' and r_B_data_valid = '1') then
		
			r_A_sign <= r_A(31);
			r_A_exp <= '0' &  r_A(30 downto 23);
			r_A_mantissa <= '0' &  r_A(22 downto 0);
					
			r_B_sign <= r_B(31);
			r_B_exp <= '0' & r_B(30 downto 23);
			r_B_mantissa <= '0' & r_B(22 downto 0);
					
			--making both exponents same for adding the mantissa directly
			if unsigned(r_A_exp) > unsigned(r_B_exp) then
				r_exp_difference := signed(r_A_exp) - signed(r_B_exp);
				if r_exp_difference > 23 then
				--in case the r_exp_difference is greater then during alignment the smaller number can be neglected
					r_sum_mantissa <= r_A_mantissa;
					r_sum_exp <= r_A_exp;
					r_sum_sign <= r_A_sign;
					w_addition <= '1';
				else
				--downshift of B
					r_sum_exp <= r_A_exp;
					r_B_mantissa(23 downto (24 - to_integer(r_exp_difference))) <= (others => '0');
					r_B_mantissa((23 - to_integer(r_exp_difference)) downto 0) <= r_B_mantissa(23 downto to_integer(r_exp_difference));
		
				end if;
			elsif unsigned(r_A_exp) < unsigned(r_B_exp) then
				r_exp_difference := signed(r_B_exp) - signed(r_A_exp);
				if r_exp_difference > 23 then
					r_sum_mantissa <= r_B_mantissa;
					r_sum_exp <= r_B_exp;
					r_sum_sign <= r_B_sign;
					w_addition <= '1';
				else
				--downshift of A
					r_sum_exp <= r_B_exp;
					r_A_mantissa(23 downto (24 - to_integer(r_exp_difference))) <= (others => '0');
					r_A_mantissa((23 - to_integer(r_exp_difference)) downto 0) <= r_A_mantissa(23 downto to_integer(r_exp_difference));
			
				end if;
			else
				r_sum_exp <= r_A_exp;
	
			end if;
			
			--summation of the two numbers
			if w_addition = '0' then
				if(r_A_sign xor r_B_sign) = '0' then --both are of same sign
					r_sum_mantissa <= std_logic_vector(unsigned(r_A_mantissa) + unsigned(r_B_mantissa));
					r_sum_sign <= r_A_sign;
				elsif unsigned(r_A_mantissa) >= unsigned(r_B_mantissa) then
					r_sum_mantissa <= std_logic_vector(unsigned(r_A_mantissa) - unsigned(r_B_mantissa));
					r_sum_sign <= r_A_sign;
				else
					r_sum_mantissa <= std_logic_vector(unsigned(r_B_mantissa) - unsigned(r_A_mantissa));
					r_sum_sign <= r_B_sign;
				end if;
			
				--normalization of the summation, in order to check for overflow that happend after addition (hence is within the if statment)
				if r_sum_mantissa(23) = '1' then --presence of carry over, hence downshift
					r_sum_mantissa <= '0' & r_sum_mantissa(23 downto 1);
					r_sum_exp <= std_logic_vector(unsigned(r_sum_exp) + 1);
				end if;
			end if;
			
			--output formatting
			o_sum(22 downto 0) <= r_sum_mantissa(22 downto 0);
			o_sum(30 downto 23) <= r_sum_exp(7 downto 0);
			o_sum(31) <= r_sum_sign;
		end if;
		
	end process;			
	
end architecture;



