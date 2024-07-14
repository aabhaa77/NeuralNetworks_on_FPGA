library ieee;
use ieee.std_logic_1164.all;

--positive edge trigger D flipflop

entity DFFON is
	port( D : in std_logic;
			CLK : in std_logic;
			CLRN : in std_logic;
			PREN : in std_logic;
			Q : buffer std_logic;
			QN : buffer std_logic);	
end DFFON;


architecture func of DFFON is

begin
	
	process(CLRN, PREN, CLK)
	begin
		if CLRN = '0'then -- active low function
			Q<='0';
		elsif PREN = '0'then -- active low function
			Q<='1';
		elsif CLK'event and CLK = '1'then
			Q<= D;
		end if;
	end process;
	
	QN<= not Q;
end func;