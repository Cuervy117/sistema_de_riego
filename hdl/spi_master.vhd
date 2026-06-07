library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    generic (
        CLK_DIVIDER : integer := 50 -- 50 MHz / 50 = 1 MHz SPI Clock
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        tx_data  : in  std_logic_vector(23 downto 0);
        rx_data  : out std_logic_vector(23 downto 0);
        busy     : out std_logic;
        done     : out std_logic;
        
        -- SPI Physical Interface
        sclk     : out std_logic;
        cs_n     : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic
    );
end entity spi_master;

architecture rtl of spi_master is
    type state_type is (ST_IDLE, ST_PREPARE, ST_CLK_LOW, ST_CLK_HIGH, ST_FINISH);
    signal state : state_type := ST_IDLE;
    
    signal clk_cnt   : integer range 0 to CLK_DIVIDER := 0;
    signal bit_cnt   : integer range 0 to 24 := 0;
    signal tx_reg    : std_logic_vector(23 downto 0) := (others => '0');
    signal rx_reg    : std_logic_vector(23 downto 0) := (others => '0');
    
    signal sclk_i    : std_logic := '0';
    signal cs_n_i    : std_logic := '1';
    signal mosi_i    : std_logic := '0';
    
begin
    -- Assign internal signals to output ports
    sclk <= sclk_i;
    cs_n <= cs_n_i;
    mosi <= mosi_i;

    process(clk, rst)
    begin
        if rst = '1' then
            state    <= ST_IDLE;
            clk_cnt  <= 0;
            bit_cnt  <= 0;
            tx_reg   <= (others => '0');
            rx_reg   <= (others => '0');
            rx_data  <= (others => '0');
            sclk_i   <= '0';
            cs_n_i   <= '1';
            mosi_i   <= '0';
            busy     <= '0';
            done     <= '0';
        elsif rising_edge(clk) then
            done <= '0'; -- Default done pulse
            
            case state is
                when ST_IDLE =>
                    busy     <= '0';
                    cs_n_i   <= '1';
                    sclk_i   <= '0';
                    mosi_i   <= '0';
                    clk_cnt  <= 0;
                    bit_cnt  <= 0;
                    
                    if start = '1' then
                        tx_reg   <= tx_data;
                        rx_reg   <= (others => '0');
                        busy     <= '1';
                        cs_n_i   <= '0'; -- Activate Chip Select
                        mosi_i   <= tx_data(23); -- Set first bit immediately
                        state    <= ST_PREPARE;
                    end if;
                    
                when ST_PREPARE =>
                    -- Wait for half clock cycle before starting SCLK toggling
                    if clk_cnt = (CLK_DIVIDER / 2) - 1 then
                        clk_cnt <= 0;
                        state   <= ST_CLK_LOW;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                    
                when ST_CLK_LOW =>
                    sclk_i <= '0';
                    if clk_cnt = (CLK_DIVIDER / 2) - 1 then
                        clk_cnt <= 0;
                        sclk_i  <= '1';
                        -- Sample MISO on rising edge of SCLK
                        rx_reg(23 - bit_cnt) <= miso;
                        state   <= ST_CLK_HIGH;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                    
                when ST_CLK_HIGH =>
                    sclk_i <= '1';
                    if clk_cnt = (CLK_DIVIDER / 2) - 1 then
                        clk_cnt <= 0;
                        sclk_i  <= '0';
                        
                        if bit_cnt = 23 then
                            -- Transaction complete
                            state <= ST_FINISH;
                        else
                            -- Update MOSI on falling edge of SCLK
                            bit_cnt <= bit_cnt + 1;
                            mosi_i  <= tx_reg(22 - bit_cnt);
                            state   <= ST_CLK_LOW;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                    
                when ST_FINISH =>
                    -- Wait half cycle after final falling edge to pull CS_N high
                    if clk_cnt = (CLK_DIVIDER / 2) - 1 then
                        clk_cnt  <= 0;
                        cs_n_i   <= '1';
                        mosi_i   <= '0';
                        rx_data  <= rx_reg;
                        done     <= '1';
                        busy     <= '0';
                        state    <= ST_IDLE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
                    
                when others =>
                    state <= ST_IDLE;
            end case;
        end if;
    end process;
end architecture rtl;
