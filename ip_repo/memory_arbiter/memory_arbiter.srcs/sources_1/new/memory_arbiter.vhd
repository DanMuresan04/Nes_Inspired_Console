library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity memory_arbiter is
  Port (
        clk100mhz        : in std_logic;
        aresetn          : in std_logic; 
        
        -- Arbiter Control
        selector         : in std_logic;
        
        -- CPU / AXI Inputs
        axi_wdata        : in std_logic_vector(31 downto 0);
        axi_we           : in std_logic; 
        
        -- GPU / Sprite Renderer Ports
        ppu_bram_addr_a  : in std_logic_vector(15 downto 0);
        ppu_bram_rdata   : out std_logic_vector(7 downto 0); 
        
        -- Physical BRAM Ports (Port A)
        bram_addr_a      : out std_logic_vector(15 downto 0);
        bram_we_a        : out std_logic;
        bram_wdata_a     : out std_logic_vector(7 downto 0);
        bram_rdata_a     : in std_logic_vector(7 downto 0);
        bram_en_a        : out std_logic
   );
end memory_arbiter;

architecture Behavioral of memory_arbiter is
    signal internal_addr : unsigned(15 downto 0) := (others => '0');
    signal unpack_active : std_logic := '0';
    signal unpack_state  : integer range 0 to 3 := 0;
    signal latched_word  : std_logic_vector(31 downto 0) := (others => '0');
    signal axi_we_d1     : std_logic := '0';
    signal axi_we_pulse  : std_logic := '0';
    signal unpacker_we   : std_logic := '0';
    signal unpacker_data : std_logic_vector(7 downto 0) := (others => '0');
begin
    
    process(clk100mhz)
    begin
        if rising_edge(clk100mhz) then
            axi_we_d1 <= axi_we;
        end if;
    end process;
    
    axi_we_pulse <= '1' when (axi_we = '1' and axi_we_d1 = '0') else '0';

    process(clk100mhz)
    begin
        if rising_edge(clk100mhz) then
            if aresetn = '0' then
                internal_addr <= (others => '0');
                unpack_active <= '0';
                unpacker_we   <= '0';
                unpack_state  <= 0;
            else
                if axi_we_pulse = '1' then
                    latched_word  <= axi_wdata;
                    unpack_active <= '1';
                    unpack_state  <= 0;
                end if;

                if unpack_active = '1' then
                    unpacker_we <= '1'; 
                    case unpack_state is
                        when 0 =>
                            unpacker_data <= latched_word(7 downto 0);
                            unpack_state  <= 1;
                        when 1 =>
                            internal_addr <= internal_addr + 1;
                            unpacker_data <= latched_word(15 downto 8);
                            unpack_state  <= 2;
                        when 2 =>
                            internal_addr <= internal_addr + 1;
                            unpacker_data <= latched_word(23 downto 16);
                            unpack_state  <= 3;
                        when 3 =>
                            internal_addr <= internal_addr + 1;
                            unpacker_data <= latched_word(31 downto 24);
                            unpack_active <= '0'; 
                        when others =>
                            unpack_active <= '0';
                    end case;
                else
                    unpacker_we <= '0'; 
                    if unpack_state = 3 and axi_we_pulse = '0' then
                        internal_addr <= internal_addr + 1;
                        unpack_state <= 0; 
                    end if;
                end if;
            end if;
        end if;
    end process;

    bram_addr_a <= std_logic_vector(internal_addr) when selector = '1' else ppu_bram_addr_a;
    bram_we_a   <= unpacker_we when selector = '1' else '0';
    bram_wdata_a<= unpacker_data when selector = '1' else x"00";
    ppu_bram_rdata <= bram_rdata_a;
    bram_en_a   <= '1';

end Behavioral;