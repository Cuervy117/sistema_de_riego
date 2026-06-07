library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_central is
    generic (
        CLK_FREQ          : integer := 50000000; -- 50 MHz system clock
        TIMEOUT_RIEGO_S   : integer := 10;       -- Max duration for watering in seconds (safety timeout)
        COOLDOWN_DURATION : integer := 5         -- Safety cooldown duration in seconds
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Inputs from threshold_comparator
        humedad_baja : in  std_logic;
        temp_alta    : in  std_logic;
        uv_extrema   : in  std_logic;
        
        -- Outputs to actuators
        bomba_on     : out std_logic;
        gate_open    : out std_logic;
        
        -- Debug state output for LEDs/displays
        state_debug  : out std_logic_vector(2 downto 0)
    );
end entity fsm_central;

architecture rtl of fsm_central is
    -- FSM State Definitions
    type state_type is (ST_IDLE, ST_MONITOR, ST_RIEGO, ST_VENTILACION, ST_COOLDOWN);
    signal current_state, next_state : state_type := ST_IDLE;
    
    -- 1 Hz Clock Enable Generator for counting seconds
    signal sec_counter   : integer range 0 to CLK_FREQ := 0;
    signal sec_tick      : std_logic := '0';
    
    -- Seconds counter for timeouts
    signal timer_seconds : integer range 0 to 65535 := 0;
    signal timer_reset   : std_logic := '0';
    
begin
    -- 1 Hz Tick Generation
    process(clk, rst)
    begin
        if rst = '1' then
            sec_counter <= 0;
            sec_tick    <= '0';
        elsif rising_edge(clk) then
            sec_tick <= '0';
            if sec_counter = CLK_FREQ - 1 then
                sec_counter <= 0;
                sec_tick    <= '1';
            else
                sec_counter <= sec_counter + 1;
            end if;
        end if;
    end process;
    
    -- Timer for tracking seconds in RIEGO and COOLDOWN
    process(clk, rst)
    begin
        if rst = '1' then
            timer_seconds <= 0;
        elsif rising_edge(clk) then
            if timer_reset = '1' then
                timer_seconds <= 0;
            elsif sec_tick = '1' then
                timer_seconds <= timer_seconds + 1;
            end if;
        end if;
    end process;

    -- State transitions (sequential process)
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= ST_IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- FSM Combinational Process for Next State and Outputs
    process(current_state, humedad_baja, temp_alta, uv_extrema, timer_seconds)
    begin
        -- Defaults
        next_state   <= current_state;
        bomba_on     <= '0';
        gate_open    <= '0';
        timer_reset  <= '0';
        state_debug  <= "000";
        
        case current_state is
            when ST_IDLE =>
                state_debug <= "000";
                timer_reset <= '1';
                next_state  <= ST_MONITOR;
                
            when ST_MONITOR =>
                state_debug <= "001";
                timer_reset <= '1';
                
                -- Check alarms (Priority: Temp first, then Watering if no UV block)
                if temp_alta = '1' then
                    next_state <= ST_VENTILACION;
                elsif humedad_baja = '1' and uv_extrema = '0' then
                    next_state <= ST_RIEGO;
                end if;
                
            when ST_RIEGO =>
                state_debug <= "010";
                bomba_on    <= '1';
                
                -- Water until soil is wet (humedad_baja = 0) or safety timeout occurs
                if humedad_baja = '0' or timer_seconds >= TIMEOUT_RIEGO_S then
                    next_state  <= ST_COOLDOWN;
                    timer_reset <= '1'; -- Reset timer for cooldown
                end if;
                
            when ST_VENTILACION =>
                state_debug <= "011";
                gate_open   <= '1';
                
                -- Ventilate until temperature goes down (temp_alta = 0)
                if temp_alta = '0' then
                    next_state  <= ST_COOLDOWN;
                    timer_reset <= '1'; -- Reset timer for cooldown
                end if;
                
            when ST_COOLDOWN =>
                state_debug <= "100";
                -- Actuators remain OFF here
                
                -- Wait for cooldown duration to avoid relay chatter
                if timer_seconds >= COOLDOWN_DURATION then
                    next_state <= ST_MONITOR;
                end if;
                
            when others =>
                next_state <= ST_IDLE;
        end case;
    end process;

end architecture rtl;
