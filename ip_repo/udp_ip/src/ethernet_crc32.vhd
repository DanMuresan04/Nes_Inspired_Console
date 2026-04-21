library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ethernet_crc32 is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        data_in     : in  std_logic_vector(7 downto 0);
        crc_out     : out std_logic_vector(31 downto 0);
        packet_good : out std_logic
    );
end ethernet_crc32;

architecture Behavioral of ethernet_crc32 is
    signal crc_reg : std_logic_vector(31 downto 0) := x"FFFFFFFF";

    function next_crc(data : std_logic_vector(7 downto 0); current_crc : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable v_crc : std_logic_vector(31 downto 0) := current_crc;
    begin
        for i in 0 to 7 loop
            if (v_crc(0) xor data(i)) = '1' then
                v_crc := ('0' & v_crc(31 downto 1)) xor x"EDB88320";
            else
                v_crc := '0' & v_crc(31 downto 1);
            end if;
        end loop;
        return v_crc;
    end function;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                crc_reg <= x"FFFFFFFF";
            elsif enable = '1' then
                crc_reg <= next_crc(data_in, crc_reg);
            end if;
        end if;
    end process;

    crc_out <= not crc_reg;
    packet_good <= '1' when crc_reg = x"DEBB20E3" else '0';

end Behavioral;