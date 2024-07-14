library ieee;
use ieee.std_logic_1164.all;

entity Serial2parallel is

	generic( G_N : integer:=32); --generalized to be used for 32 bit floating points
	port(
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_data_enable : in std_logic;
		i_data : in std_logic;
		o_data_valid : out std_logic;
		o_data : out std_logic_vector(G_N - 1 downto 0));
end Serial2parallel;

architecture rtl of Serial2parallel is
	
	signal r_data_enable : std_logic;
	signal r_data : std_logic_vector(G_N-1 downto 0);
	signal r_count : integer range 0 to G_N -1;
	
	begin
	serial2parallel : process(i_clk, i_reset)
	begin
	
	
	if (i_reset = '0') then --active low reset
		r_data_enable <= '0';
		r_count <= 0;
		r_data <= (others => '0');
		o_data_valid <= '0';
		o_data <= (others =>'0');
	elsif (rising_edge(i_clk)) then
		o_data_valid <= r_data_enable;
		
		if (r_data_enable = '1') then
			o_data <= r_data; --when the r_data_enable to high, then the register has all the value from the series and it is given to the parallel
		end if;
		
		if (i_data_enable = '1') then --i guess i_data_enable means the data given now goes into the convertor
			r_data <= r_data(G_N - 2 downto 0) & i_data; --the data is being added to the right
			if (r_count >= G_N - 1) then
				r_count <= 0;
				r_data_enable <='1';-- reset condition once all the data is fed into the convertor
			else
				r_count <= r_count + 1;
				r_data_enable <= '0'; -- increment condition while data is being fed into the convertor
			end if;
		else
			r_data_enable <= '0';
		end if;
	end if;
	end process serial2parallel;
	
end rtl;
--___________________

