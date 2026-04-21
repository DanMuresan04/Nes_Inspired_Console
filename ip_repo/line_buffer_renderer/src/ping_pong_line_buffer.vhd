----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/18/2026 11:30:12 AM
-- Design Name: 
-- Module Name: ping_pong_line_buffer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity ping_pong_line_buffer is
  Port (clk_sprite   : in std_logic;
        clk_vga       : in std_logic;
        
        prod_wr_we      : in std_logic;
        prod_wr_addr : in std_logic_vector(10 downto 0);
        prod_wr_din  : in std_logic_vector(8 downto 0);
        prod_rd_addr : in std_logic_vector(10 downto 0);
        prod_rd_dout : out std_logic_vector(8 downto 0);
        
        cons_addr    : in std_logic_vector(10 downto 0);
        cons_dout    : out std_logic_vector(8 downto 0)
   );
end ping_pong_line_buffer;

architecture Behavioral of ping_pong_line_buffer is
    
    type ram_type is array(0 to 2047) of std_logic_vector(8 downto 0);
    signal line_ram : ram_type := (others => (others => '0'));
    attribute ram_style : string;
    attribute ram_style of line_ram : signal is "block";
    
begin
    --write 100mhz
    process(clk_sprite)
    begin
        if rising_edge(clk_sprite) then
            if prod_wr_we = '1' then 
                line_ram(to_integer(unsigned(prod_wr_addr))) <= prod_wr_din;
            end if;
            
            prod_rd_dout <= line_ram(to_integer(unsigned(prod_rd_addr)));
        end if;    
    end process;
    
    --read 25mhz
    process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            cons_dout <= line_ram(to_integer(unsigned(cons_addr)));
        end if;
    end process;
    
end Behavioral;
