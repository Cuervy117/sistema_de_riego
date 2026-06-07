library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_controller is
    generic (
        CLK_FREQ      : integer := 50000000; -- 50 MHz
        PWM_FREQ      : integer := 50;       -- 50 Hz (20 ms period)
        PULSE_MIN_US  : integer := 1000;     -- 1.0 ms pulse (e.g. 0 degrees / closed compuerta)
        PULSE_MAX_US  : integer := 2000      -- 2.0 ms pulse (e.g. 180 degrees / open compuerta)
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Control input ('0' for closed/min speed, '1' for open/max speed)
        gate_open : in  std_logic;
        
        -- PWM output signal to servomotor
        pwm_out  : out std_logic
    );
end entity pwm_controller;

architecture rtl of pwm_controller is
    -- Calculate cycle counts in constant time
    constant PERIOD_CYCLES    : integer := CLK_FREQ / PWM_FREQ;
    constant PULSE_MIN_CYCLES : integer := ((CLK_FREQ / 1000) * PULSE_MIN_US) / 1000;
    constant PULSE_MAX_CYCLES : integer := ((CLK_FREQ / 1000) * PULSE_MAX_US) / 1000;
    
    signal counter      : integer range 0 to PERIOD_CYCLES := 0;
    signal pulse_width  : integer range 0 to PERIOD_CYCLES := PULSE_MIN_CYCLES;
    
begin
    -- Determine target pulse width based on control signal with dynamic sweeping
    process(clk, rst)
        variable step        : integer := 0;
        variable sweep_up    : boolean := true;
    begin
        if rst = '1' then
            pulse_width <= PULSE_MIN_CYCLES;
            sweep_up    := true;
        elsif rising_edge(clk) then
            if gate_open = '1' then
                -- Update pulse width at the end of each PWM period (when counter rolls over)
                if counter = PERIOD_CYCLES - 1 then
                    -- Calculate step size so a full sweep (min to max) takes ~1 second.
                    -- 1 second contains PWM_FREQ cycles, so step = (max - min) / PWM_FREQ.
                    -- Ensure step is at least 1 cycle.
                    step := (PULSE_MAX_CYCLES - PULSE_MIN_CYCLES) / PWM_FREQ;
                    if step = 0 then
                        step := 1;
                    end if;
                    
                    if sweep_up then
                        if pulse_width + step >= PULSE_MAX_CYCLES then
                            pulse_width <= PULSE_MAX_CYCLES;
                            sweep_up    := false;
                        else
                            pulse_width <= pulse_width + step;
                        end if;
                    else
                        if pulse_width - step <= PULSE_MIN_CYCLES then
                            pulse_width <= PULSE_MIN_CYCLES;
                            sweep_up    := true;
                        else
                            pulse_width <= pulse_width - step;
                        end if;
                    end if;
                end if;
            else
                -- Return to closed position
                pulse_width <= PULSE_MIN_CYCLES;
                sweep_up    := true;
            end if;
        end if;
    end process;

    -- Generate PWM Signal
    process(clk, rst)
    begin
        if rst = '1' then
            counter <= 0;
            pwm_out <= '0';
        elsif rising_edge(clk) then
            if counter = PERIOD_CYCLES - 1 then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
            
            -- Set output high at start of cycle, pull low after pulse_width matches
            if counter < pulse_width then
                pwm_out <= '1';
            else
                pwm_out <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
