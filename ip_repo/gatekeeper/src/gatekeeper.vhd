library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gatekeeper is
  Port (
        clk           : in std_logic;
        resetn        : in std_logic;
        
        -- Slave Interface 0: From Main Payload FIFO
        s_axis_tdata  : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic;
        s_axis_tlast  : in std_logic;
        s_axis_tready : out std_logic; 
        
        -- Slave Interface 1: From Metadata FIFO
        s_meta_tdata  : in std_logic_vector(7 downto 0);
        s_meta_tvalid : in std_logic;
        s_meta_tready : out std_logic;
        
        -- Master Interface: To Data Width Converter
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tready : in std_logic
  );
end gatekeeper;

architecture Behavioral of gatekeeper is
    
    type state_t is (WAIT_FOR_PACKET, FORWARD_PACKET, DROP_PACKET);
    signal state : state_t := WAIT_FOR_PACKET;
    
begin
    
    m_axis_tdata <= s_axis_tdata;
    m_axis_tlast <= s_axis_tlast;
    
   
    process(state, s_axis_tvalid, m_axis_tready, s_meta_tvalid)
    begin
        s_axis_tready <= '0';
        m_axis_tvalid <= '0';
        s_meta_tready <= '0';

        case state is
            when WAIT_FOR_PACKET =>
                if s_axis_tvalid = '1' and s_meta_tvalid = '1' then
                    s_meta_tready <= '1';
                end if;

            when FORWARD_PACKET =>
                m_axis_tvalid <= s_axis_tvalid;
                s_axis_tready <= m_axis_tready;

            when DROP_PACKET =>
                m_axis_tvalid <= '0';
                s_axis_tready <= '1';
                
        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                state <= WAIT_FOR_PACKET;
            else
                case state is 
                    when WAIT_FOR_PACKET =>
                        if s_axis_tvalid = '1' and s_meta_tvalid = '1' then
                            if s_meta_tdata(0) = '1' then
                                state <= FORWARD_PACKET;
                            else 
                                state <= DROP_PACKET;
                            end if;
                        end if;
                        
                     when FORWARD_PACKET =>
                        if s_axis_tvalid = '1' and m_axis_tready = '1' and s_axis_tlast = '1' then
                            state <= WAIT_FOR_PACKET;
                        end if;
                        
                     when DROP_PACKET =>
                        if s_axis_tvalid = '1' and s_axis_tlast = '1' then 
                            state <= WAIT_FOR_PACKET;
                        end if;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;