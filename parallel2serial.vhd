library ieee;
use ieee.std_logic_1164.all;

entity parallel2serial is

	generic(G_N: integer := 32);
	port (i_clk: in std_logic;
			i_rst: in std_logic;
			--i_data_enable: in std_logic;
			i_data: in  std_logic_vector(G_N - 1 downto 0);
			o_data_valid: out std_logic;
			o_data: out std_logic;
			o_error_serialize_pulse: out std_logic);
	end parallel2serial;

	architecture rtl of parallel2serial is
		signal r_data_enable: std_logic;
		signal r_data: std_logic_vector(G_N - 1 downto 0);
		signal r_count: integer range 0 to G_N; -- do we need to initalize here itself that is G_N-1?
		signal i_data_enable : std_logic := '1';
		
		begin
			o_data_valid <= r_data_enable;
			o_data <= r_data(G_N - 1); --MSB being assignedto o_data
						
			parallel2serial : process(i_clk,i_rst, r_count)
			
			begin
			
			if(i_rst= '0') then --active low reset signal
				r_count <= G_N - 1;--greater that g_n-1 such that r_data_enable = '0'
				r_data_enable <= '0';
				r_data <= (others=>'0');
				o_error_serialize_pulse <= '0';	--no error
				
			--when the conversion is complete
			if (r_count > G_N - 2) then
				r_data_enable <= '1';
			end if;
			
			elsif(rising_edge(i_clk)) then
				if (r_count > G_N - 2) then
					r_data_enable <= '1';
				end if;
				--error_serialized pulse goes high, when the user wants to give in data, but the prev data is still being processed
				if(r_count < G_N - 1) and (i_data_enable = '1') then
					o_error_serialize_pulse  <= '1';
				else
					o_error_serialize_pulse  <= '0';
				end if;
				
			--to control the i_enable_data
				if (r_count < G_N) then
					i_data_enable <= '0';
				else
					i_data_enable <= '1';
				end if;
				
			--control the r_count
				if (i_data_enable = '1') then
					r_count <= 0;
--					r_data_enable <= '1';
					r_data <= i_data;
				elsif (i_data_enable = '0' and r_count < G_N -1) then
					r_count <= r_Count + 1;
					r_data_enable <= '0';
					r_data <= r_data(G_N - 2 downto 0) & '0';
				else
					r_count <= r_count + 1;
					r_data_enable <= '0';
					r_count <= G_N - 1;
				end if;
				
				if (r_count > G_N - 2) then
					r_data_enable <= '1';
				end if;
--				if (r_count = 0) then
--					r_data_enable <= '1';
--				end if;
				
			end if;
					
			
			end process parallel2serial;

end rtl;




