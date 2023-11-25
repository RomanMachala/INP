-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Roman Machala <xmacha86@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;

-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

type state_fsm is (	--definice jednotlivych stavu pro fsm
	state_start,		--zakladni stav automatu
	state_fetch,		--ziskani dalsi instrukce
	state_decode,		--dekodovani instrukce
	state_inc_init,		--pomocny stav pro inicializaci automatu
	state_found_at,			--nalezli jsme znak @ pro inicializace
	--EXECUTE STAVY--
	state_init,		--stav, ktery inicializuje procesor
	state_inc_ptr,		--inkrementuje ptr ukazatele
	state_dec_ptr,		--dekrementace ukazatele
	state_inc_act,		--inkrementace aktualni bunky
	state_inc_act_2,
	state_dec_act,		--dekrementace aktualni bunky
	state_dec_act_2,	
	state_while_zero,	--pokud je hodnota aktualni bunky nulova, skoc za odpovidajici prikaz, jinak pokracuj nasledujicim prikazem
	state_while_zero_2,
	state_while_zero_3,
	state_not_zero,		--pokud je hodnota aktualni bunky nenulova, skoc za odpovidajici prikaz, jinak pokracuj nasledujicim prikazem
	state_not_zero_2,
	state_not_zero_3,
	state_quit_while,	--ukonci prave provadenou smycku while
	state_quit_while_2,
	state_print_act,	--vytiskne aktualni hodnotu bunky
	state_print_act_2,	
	state_load_act,	--nacti hodnotu a uloz ji do aktualni bunky
	state_load_act_2,
	state_halt		--oddelovac kodu a dat, zpusobi zastaveni vykonovani programu
);

signal active_state : state_fsm;	--predchozi stav automatu
signal next_state : state_fsm;  	--nasledujici stav automatu

--ptr registr
signal PTR : std_logic_vector(12 downto 0);
signal ptr_inc : std_logic;	--signal pro inkrementaci ukazatele do pameti
signal ptr_dec : std_logic; --signal pro dekrementaci

--pc registr
signal PC : std_logic_vector(12 downto 0);
signal pc_inc : std_logic; --signal pro inkrementaci program counteru
signal pc_dec : std_logic; --dekrementace
signal pc_res : std_logic; --reset program counteru

--mux1
signal sel1 : std_logic; --signal pro MUX1 (rozhoduje, zdali DATA_ADDR = PTR nebo DATA_ADDR = PC)
--mux2
signal sel2 : std_logic_vector(1 downto 0); 

begin

	pc_process:process (CLK, RESET, pc_inc, pc_dec) --proces program counteru
	begin
	if (RESET = '1') then 
		PC <= (others => '0');
	elsif (CLK'event) and (CLK = '1') then
		if (pc_inc = '1') then
			PC <= PC + 1;
		elsif (pc_dec = '1') then
			PC <= PC - 1;
		elsif (pc_res = '1') then
			PC <= (others => '0');
		end if;
	end if;
	end process pc_process;

	ptr_process:process (CLK, RESET, ptr_inc, pc_dec) --proces ukazatele do pameti
	begin
	if (RESET = '1') then
		PTR <= (others => '0');
	elsif (CLK'event) and (CLK = '1') then
		if (ptr_inc = '1') then
			PTR <= PTR + 1;
		elsif (ptr_dec = '1') then
			PTR <= PTR - 1;
		else
			PTR <= PTR;
		end if;
	end if;
	end process ptr_process;

--	DATA_ADDR <= PTR when (sel1 = "10") else PC when (sel1 = "01") else (others => '0');
	--DATA_ADDR <= PTR;
	process(sel1, PC, PTR) --multiplexor 1 (rozhoduje, jestli se jedna o pametovou cast nebo o programovou)
	begin
		case sel1 is
			when '0' => DATA_ADDR <= PC;
			when '1' => DATA_ADDR <= PTR;
			when others => null;
		end case;

	end process;
	--DATA_WDATA <= IN_DATA when (sel2 = "00") else DATA_RDATA - 1 when (sel2 = "01") else DATA_RDATA + 1 when (sel2 = "10") else (others => '0');
	--DATA_WDATA <= DATA_RDATA;
	process(sel2, DATA_RDATA, IN_DATA) --MUX2 (rozhoduje, jestli se zapisuji vstupni data, inkrementace/dekrementace dat v aktualni bunce nebo jen klasicka data)
	begin
		case sel2 is
			when "00" => DATA_WDATA <= IN_DATA;
			when "01" => DATA_WDATA <= DATA_RDATA - 1;
			when "10" => DATA_WDATA <= DATA_RDATA + 1;
			when "11" => DATA_WDATA <= DATA_RDATA;
			when others => null;
		end case;
	end process;

	
	fsm_state_change: process (CLK ,RESET, EN) --hlavni proces konecneho automatu (zmena z aktivniho stavu na nasledujici pri nabezne hrane CLK signalu)
	begin
	if (RESET = '1') then
		active_state <= state_start;
	elsif (CLK'event) and (CLK = '1') then
		if EN = '1' then
			active_state <= next_state; 
		end if;
	end if;
	end process fsm_state_change;

	
	fsm: process(active_state, DATA_RDATA, OUT_BUSY, IN_VLD)
	begin
		--pri kazde zmene stavu zresetujeme jednotlive povolovaci signaly
		DATA_EN <= '0';
		DATA_RDWR <= '0';
		IN_REQ <= '0';
		OUT_WE <= '0';
		OUT_DATA <= (others => '0');
			
		--implicitne nastavene signaly jednolivych komponent
		pc_res <= '0';
		pc_inc <= '0';
		pc_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		sel1 <= '0';
		sel2 <= "11";
		case active_state is
			when state_start => --startovaci stav
				DATA_EN <= '1'; --povoleni cinnosti procesoru
				DATA_RDWR <= '0'; --cteni dat
				sel1 <= '0'; --PC
				DONE <= '0'; --jeste jsme neskoncili
				READY <= '0'; --jeste nebylo inicializovano
				next_state <= state_init;
			when state_init =>	--inicializace ptr za znak @
				DATA_EN <= '1';
				case DATA_RDATA is
					when x"40" => --pokud jsme narazili na znak @
						next_state <= state_found_at;
					when others =>
						next_state <= state_inc_init;
				end case;
			when state_inc_init => --inkrementace PC pri inicializaci procesoru
				DATA_EN <= '1'; --povoleni cinnsoti procesoru
				ptr_inc <= '1'; --inkrementace ukazatele
				pc_inc <= '1'; --inkrementace pc (pro cteni dalsi instrukce)
				next_state <= state_start;
			when state_found_at => --nalezeni znaku @
				DATA_EN <= '1'; --povoleni cinnsoti procesoru
				READY <= '1'; --inicializace je hotova
				pc_res <= '1'; --resetujeme PC na 0
				ptr_inc <= '1'; --inkrementace PTR za znak @
				next_state <= state_fetch;
			when state_fetch => --fetch instrukce
				DATA_EN <= '1'; --povoleni cinosti procesoru
				DATA_RDWR <= '0'; --cteme data (nemus zde byt)
				sel1 <= '0'; --PC
				next_state <= state_decode;
			when state_decode =>
				case DATA_RDATA is --pri ruznych znacich prechazime do jinych stavu
					when x"3E" =>
						next_state <= state_inc_ptr;
					when x"3C" =>
						next_state <= state_dec_ptr;
					when x"2B" =>
						next_state <= state_inc_act;
					when x"2D" =>
						next_state <= state_dec_act;
					when x"2E" =>
						next_state <= state_print_act;
					when x"2C" =>
						next_state <= state_load_act;
					when x"5B" =>
						next_state <= state_while_zero;
					when x"5D" =>
						next_state <= state_not_zero;
					when x"7E" =>
						next_state <= state_quit_while;
					when x"40" =>
						next_state <= state_halt;
					when x"00" =>
						next_state <= state_halt;
					when others =>
						next_state <= state_fetch;
						pc_inc <= '1';
				end case;
			when state_inc_ptr =>
				ptr_inc <= '1'; --PTR++
				pc_inc <= '1'; --PC++
				next_state <= state_fetch;
			when state_dec_ptr =>
				ptr_dec <= '1'; --PTR--
				pc_inc <= '1'; --PC--
				next_state <= state_fetch;
			when state_inc_act =>
				pc_inc <= '1'; --PC++
				sel1 <= '1'; --PTR
				DATA_RDWR <= '0'; --READ
				DATA_EN <= '1'; --povoleni cinnsoti
				next_state <= state_inc_act_2;	
			when state_inc_act_2 =>
				sel1 <= '1'; --PTR
				sel2 <= "10"; --DATA_RDATA + 1
				DATA_EN <= '1'; --povoleni cinnosti
				DATA_RDWR <= '1'; -- WRITE
				next_state <= state_fetch;
			when state_dec_act =>
				pc_inc <= '1'; --PC++
				sel1 <= '1'; --PTR
				DATA_RDWR <= '0'; --READ
				DATA_EN <= '1'; --povoleni cinnosti
				next_state <= state_dec_act_2;
			when state_dec_act_2 =>
				sel1 <= '1'; --PTR
				sel2 <= "01"; --DATA_RDATA - 1
				DATA_EN <= '1'; --povolenni cinnsoti
				DATA_RDWR <= '1'; --WRITE
				next_state <= state_fetch;
			when state_print_act =>
				DATA_EN <= '1';
				if (OUT_BUSY = '1') then --Pokud jsme busy cyklime dokola dokud nejsme
					next_state <= state_print_act;
				elsif (OUT_BUSY = '0') then
					next_state <= state_print_act_2;
					sel1 <= '1'; --PTR
				end if;
			when state_print_act_2 =>
				pc_inc <= '1'; --PC++
				OUT_WE <= '1'; --povoleni cinnosti tiksu znaku
				DATA_EN <= '1'; --povoleni cinnsoti
				--OUT_DATA <= DATA_RDATA;
				sel2 <= "11"; --DATA_RDATA
				next_state <= state_fetch;
			when state_load_act =>
				IN_REQ <= '1'; --signal na request
				DATA_EN <= '1'; --povoleni cinnosti
				if(IN_VLD = '0') then
					next_state <= state_load_act;
				elsif(IN_VLD = '1') then
					next_state <= state_load_act_2;
					sel1 <= '1'; --PTR
					DATA_RDWR <= '0'; --READ
				end if;
			when state_load_act_2 =>
				DATA_EN <= '1'; --povoleni cinnosti
				sel1 <= '1'; --PTR
				sel2 <= "00"; --IN_DATA
				pc_inc <= '1'; --PC++
				DATA_RDWR <= '1'; --WRITE
				next_state <= state_fetch;
			when state_while_zero =>
				sel1 <= '1'; --PTR
				DATA_RDWR <= '0'; --READ
				DATA_EN <= '1'; --povoleni9 cinnsoti
				next_state <= state_while_zero_2;
			when state_while_zero_2 =>
				DATA_EN <= '1'; --povoleni cinnosti
				sel2 <= "11"; --DATA_RDATA
				pc_inc <= '1'; --PC++
				case DATA_RDATA is
					when x"00" => --Pokud je aktualni bunka nulova, pokracujeme cyklem
						next_state <= state_while_zero_3;
						sel1 <= '0'; --PC
						DATA_RDWR <= '0';
					when others => --pokud neni nulova, pokracujeme dalsi instrukci
						next_state <= state_fetch;
				end case;
			when state_while_zero_3 =>
				DATA_EN <= '1'; --povoleni cinnsoti
				pc_inc <= '1'; --PC++
				DATA_RDWR <= '0'; --READ
				case DATA_RDATA is
					when x"5D" => --pokud narazime na ]
						next_state <= state_fetch;
					when others =>
						next_state <= state_while_zero_3; --jinak cyklime dokoloa
				end case;
			when state_not_zero =>
				DATA_EN <= '1'; --povoleni cinnosti
				sel1 <= '1'; --PTR
				DATA_RDWR <= '0'; --READ
				next_state <= state_not_zero_2;
			when state_not_zero_2 =>
				DATA_EN <= '1'; --povoleni cinnosti
				sel2 <= "11"; --DATA_RDATA
				case DATA_RDATA is
					when x"00" => --pokud je aktualni bunka nulova
						pc_inc <= '1'; --PC++
						next_state <= state_fetch;
					when others =>
						next_state <= state_not_zero_3; --pokud neni cyklime dale
				end case;
			when state_not_zero_3 =>
				DATA_RDWR <= '0'; --READ
				DATA_EN <= '1'; --povoleni cinnosti
				case DATA_RDATA is
					when x"5B" => --pokud narazime na [, zaciname opet cyklem
						next_state <= state_while_zero;
					when others =>
						pc_dec <= '1'; --PC-- (dekrementujeme do doby, nez dalsi znak bude [)
						next_state <= state_not_zero_3;
				end case;
			when state_quit_while => --break (narazili jsme na znak tilda)
				DATA_EN <= '1'; --povoleni cinnosti
				DATA_RDWR <= '0'; --READ
				next_state <= state_quit_while_2;
			when state_quit_while_2 =>
				DATA_EN <= '1'; --povoleni cinnosti
				DATA_RDWR <= '0'; --READ
				case DATA_RDATA is
					when x"5D" => --pokud narazime na ], posuneme PC za tento znak a pokracujeme dale
						pc_inc <= '1'; --PC++
						next_state <= state_fetch;
					when others => --pokracujeme tak dlouho, dokud nenarazime na znak ]
						pc_inc <= '1'; --PC++
						next_state <= state_quit_while_2;
				end case;				
			when state_halt => --konec programu
				DONE <= '1';
		end case;										
	end process fsm;
	
end behavioral;

