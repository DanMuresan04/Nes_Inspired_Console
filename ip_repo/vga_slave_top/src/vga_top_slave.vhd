library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_slave_top is
   Port(
        pixel_clk      : in std_logic;
        reset          : in std_logic;   
        mario_x_in     : in std_logic_vector(10 downto 0);
        mario_y_in     : in std_logic_vector(10 downto 0);
        mario_frame_in : in std_logic_vector(10 downto 0);
        bram_addr      : out std_logic_vector(10 downto 0);
        bram_clk       : out std_logic;
        bram_en        : out std_logic;
        bram_data      : in  std_logic_vector(11 downto 0);
        VGA_R          : out std_logic_vector(3 downto 0); 
        VGA_G          : out std_logic_vector(3 downto 0); 
        VGA_B          : out std_logic_vector(3 downto 0); 
        VGA_VS         : out std_logic; 
        VGA_HS         : out std_logic 
  );
end vga_slave_top;

architecture Behavioral of vga_slave_top is

    component vga_controller is
      Port (
            pixel_clk  : in std_logic;
            reset      : in std_logic;
            color_in   : in std_logic_vector(11 downto 0);  
            pixel_x    : out std_logic_vector(10 downto 0); 
            pixel_y    : out std_logic_vector(10 downto 0); 
            video_on   : out std_logic;                    
            VGA_R      : out std_logic_vector(3 downto 0);
            VGA_G      : out std_logic_vector(3 downto 0);
            VGA_B      : out std_logic_vector(3 downto 0);
            VGA_HS     : out std_logic;
            VGA_VS     : out std_logic
       );
    end component;
    
    constant MARIO_WIDTH  : integer := 16;
    constant MARIO_HEIGHT : integer := 16;
    
    signal pixel_x, pixel_y : std_logic_vector(10 downto 0);
    signal video_on         : std_logic;
    
    signal vga_hsync_internal : std_logic;
    signal vga_vsync_internal : std_logic;
    signal vga_r_internal     : std_logic_vector(3 downto 0);
    signal vga_g_internal     : std_logic_vector(3 downto 0);
    signal vga_b_internal     : std_logic_vector(3 downto 0);
    
    signal vga_hs_pipe_1, vga_vs_pipe_1 : std_logic := '0';
    signal vga_r_pipe_1,  vga_g_pipe_1,  vga_b_pipe_1  : std_logic_vector(3 downto 0) := (others => '0');
    signal vga_hs_pipe_2, vga_vs_pipe_2 : std_logic := '0';
    signal vga_r_pipe_2,  vga_g_pipe_2,  vga_b_pipe_2  : std_logic_vector(3 downto 0) := (others => '0');
    signal vga_hs_pipe_3, vga_vs_pipe_3 : std_logic := '0';
    signal vga_r_pipe_3,  vga_g_pipe_3,  vga_b_pipe_3  : std_logic_vector(3 downto 0) := (others => '0');

    signal drawing_mario_pipe_1 : std_logic := '0';
    signal drawing_mario_pipe_2 : std_logic := '0';
    signal drawing_mario        : std_logic := '0';

begin

    bram_clk <= pixel_clk;
    bram_en  <= '1';

    monitor_draw : vga_controller port map(
        pixel_clk  => pixel_clk,
        reset      => reset,
        color_in   => (others => '0'),
        pixel_x    => pixel_x,
        pixel_y    => pixel_y,
        video_on   => video_on,
        VGA_R      => vga_r_internal,
        VGA_G      => vga_g_internal,
        VGA_B      => vga_b_internal,
        VGA_HS     => vga_hsync_internal,
        VGA_VS     => vga_vsync_internal
    );
    
    mario_tracking : process(pixel_x, pixel_y, video_on, mario_x_in, mario_y_in, mario_frame_in)
        variable px_u : unsigned(10 downto 0);
        variable py_u : unsigned(10 downto 0);
        variable m_x  : unsigned(10 downto 0);
        variable m_y  : unsigned(10 downto 0);
        variable offset_x : unsigned(4 downto 0);
        variable offset_y : unsigned(4 downto 0);
    begin
        px_u := unsigned(pixel_x);
        py_u := unsigned(pixel_y);
        m_x  := unsigned(mario_x_in);
        m_y  := unsigned(mario_y_in);
        
        drawing_mario <= '0';
        bram_addr     <= (others => '0');
        
        if video_on = '1' then
            if (px_u >= m_x) and (px_u < m_x + MARIO_WIDTH) and 
               (py_u >= m_y) and (py_u < m_y + MARIO_HEIGHT) then
               drawing_mario <= '1';
               
               offset_x := resize(px_u - m_x, 5);
               offset_y := resize(py_u - m_y, 5);
        
               bram_addr <= std_logic_vector(unsigned(mario_frame_in) + (offset_y(3 downto 0) & "0000") + resize(offset_x, 11));
            end if;
        end if;
    end process;
    
    vga_pipeline : process(pixel_clk, reset)
    begin
        if reset = '1' then
            vga_hs_pipe_1 <= '0'; vga_vs_pipe_1 <= '0';
            vga_hs_pipe_2 <= '0'; vga_vs_pipe_2 <= '0';
            vga_hs_pipe_3 <= '0'; vga_vs_pipe_3 <= '0';
            
            vga_r_pipe_1 <= (others => '0'); vga_g_pipe_1 <= (others => '0'); vga_b_pipe_1 <= (others => '0');
            vga_r_pipe_2 <= (others => '0'); vga_g_pipe_2 <= (others => '0'); vga_b_pipe_2 <= (others => '0');
            vga_r_pipe_3 <= (others => '0'); vga_g_pipe_3 <= (others => '0'); vga_b_pipe_3 <= (others => '0');
            
            drawing_mario_pipe_1 <= '0';
            drawing_mario_pipe_2 <= '0';
            
        elsif rising_edge(pixel_clk) then
        
            vga_hs_pipe_1 <= vga_hsync_internal;
            vga_vs_pipe_1 <= vga_vsync_internal;
            vga_r_pipe_1 <= vga_r_internal;
            vga_g_pipe_1 <= vga_g_internal;
            vga_b_pipe_1 <= vga_b_internal;
            drawing_mario_pipe_1 <= drawing_mario;
            
            vga_hs_pipe_2 <= vga_hs_pipe_1;
            vga_vs_pipe_2 <= vga_vs_pipe_1;
            vga_r_pipe_2 <= vga_r_pipe_1;
            vga_g_pipe_2 <= vga_g_pipe_1;
            vga_b_pipe_2 <= vga_b_pipe_1;
            drawing_mario_pipe_2 <= drawing_mario_pipe_1;
            
            vga_hs_pipe_3 <= vga_hs_pipe_2;
            vga_vs_pipe_3 <= vga_vs_pipe_2;
            vga_r_pipe_3 <= vga_r_pipe_2;
            vga_g_pipe_3 <= vga_g_pipe_2;
            vga_b_pipe_3 <= vga_b_pipe_2;
            
            if drawing_mario_pipe_2 = '1' and bram_data /= x"F0F" then
               vga_r_pipe_3 <= bram_data(11 downto 8);
               vga_g_pipe_3 <= bram_data(7 downto 4);
               vga_b_pipe_3 <= bram_data(3 downto 0);
            end if;
            
        end if;
    end process;
    
    VGA_R  <= vga_r_pipe_3;
    VGA_G  <= vga_g_pipe_3;
    VGA_B  <= vga_b_pipe_3;
    VGA_HS <= vga_hs_pipe_3;
    VGA_VS <= vga_vs_pipe_3;
    
end Behavioral;