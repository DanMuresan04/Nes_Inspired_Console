----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/13/2026 06:55:29 PM
-- Design Name: 
-- Module Name: vga_controller - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
  Port (
        pixel_clk  : in std_logic; -- 25MHz clock provided from the outside!
        reset      : in std_logic;
        color_in   : in std_logic_vector(11 downto 0);  
        --internal logic
        pixel_x    : out std_logic_vector(10 downto 0); 
        pixel_y    : out std_logic_vector(10 downto 0); 
        video_on   : out std_logic;                    
        --routed to monitor
        VGA_R      : out std_logic_vector(3 downto 0);
        VGA_G      : out std_logic_vector(3 downto 0);
        VGA_B      : out std_logic_vector(3 downto 0);
        VGA_HS     : out std_logic;
        VGA_VS     : out std_logic
   );
end vga_controller;

architecture Behavioral of vga_controller is

    constant H_ACTIVE : unsigned(10 downto 0) := to_unsigned(640, 11);
    constant H_FP     : unsigned(10 downto 0) := to_unsigned(16, 11);
    constant H_SYNC   : unsigned(10 downto 0) := to_unsigned(96, 11);
    constant H_BP     : unsigned(10 downto 0) := to_unsigned(48, 11);
    constant H_MAX    : unsigned(10 downto 0) := H_ACTIVE + H_FP + H_SYNC + H_BP - 1;
    
    constant V_ACTIVE : unsigned(10 downto 0) := to_unsigned(480, 11);
    constant V_FP     : unsigned(10 downto 0) := to_unsigned(10, 11);
    constant V_SYNC   : unsigned(10 downto 0) := to_unsigned(2, 11);
    constant V_BP     : unsigned(10 downto 0) := to_unsigned(33, 11);
    constant V_MAX    : unsigned(10 downto 0) := V_ACTIVE + V_FP + V_SYNC + V_BP - 1; 
    
    signal h_count      : unsigned(10 downto 0) := (others => '0');
    signal v_count      : unsigned(10 downto 0) := (others => '0');
    signal vga_hsync    : std_logic;
    signal vga_vsync    : std_logic;
    signal video_active : std_logic;
    signal red          : std_logic_vector(3 downto 0);
    signal green        : std_logic_vector(3 downto 0);
    signal blue         : std_logic_vector(3 downto 0);
    
begin
    
    -- counters
    process(reset, pixel_clk)   
    begin
        if reset = '1' then
            h_count <= (others => '0');
            v_count <= (others => '0');
        
        elsif rising_edge(pixel_clk) then
            if h_count = H_MAX then
                h_count <= (others => '0');
                if v_count = V_MAX then
                    v_count <= (others => '0');
                else 
                    v_count <= v_count + 1;    
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;
    
    -- sync zones
    vga_hsync    <= '1' when (h_count >= H_ACTIVE + H_FP) and (h_count < H_ACTIVE + H_FP + H_SYNC) else '0';
    vga_vsync    <= '1' when (v_count >= V_ACTIVE + V_FP) and (v_count < V_ACTIVE + V_FP + V_SYNC) else '0';
    video_active <= '1' when (h_count < H_ACTIVE) and (v_count < V_ACTIVE) else '0';
    
    -- output process
    output_process : process(pixel_clk)
    begin 
        if rising_edge(pixel_clk) then
            if video_active = '1' then
                red   <= color_in(11 downto 8); 
                green <= color_in(7 downto 4); 
                blue  <= color_in(3 downto 0);
            else
                red   <= "0000"; 
                green <= "0000";
                blue  <= "0000";
            end if;
        end if;
    end process;
    
    --drive the outputs
    VGA_R  <= red;
    VGA_G  <= green;
    VGA_B  <= blue;
    VGA_HS <= vga_hsync;
    VGA_VS <= vga_vsync;
    pixel_x    <= std_logic_vector(h_count);
    pixel_y    <= std_logic_vector(v_count);
    video_on   <= video_active;
    
end Behavioral;