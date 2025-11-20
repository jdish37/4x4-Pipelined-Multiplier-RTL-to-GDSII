############################################################
# SDC for 4x4 Pipelined Multiplier
# Technology   : 45nm
# Clock period : 5 ns (200 MHz)
############################################################

# ----------------------------------------------------------
# 1. Create primary clock
# ----------------------------------------------------------
create_clock -name clk -period 5.000 [get_ports clk]

# Add small uncertainty (jitter + skew margin)
set_clock_uncertainty 0.10 [get_clocks clk]


# ----------------------------------------------------------
# 2. Input delays
# ----------------------------------------------------------
# Assume inputs A and B come from another flop-based block.
# Using 20% of clock (1 ns) as input delay margin.
set_input_delay 1.0 -clock clk [get_ports {A[*]}]
set_input_delay 1.0 -clock clk [get_ports {B[*]}]

# Reset is asynchronous → delay not needed
set_input_delay 0.0 -clock clk [get_ports rst_n]


# ----------------------------------------------------------
# 3. Output delays
# ----------------------------------------------------------
# Assume output P drives flop of next stage.
set_output_delay 1.0 -clock clk [get_ports {P[*]}]


# ----------------------------------------------------------
# 4. Mark reset as asynchronous (no timing)
# ----------------------------------------------------------
set_false_path -from [get_ports rst_n]


# ----------------------------------------------------------
# 5. Design rules (45nm typical values)
# ----------------------------------------------------------
# Max transition ~100 ps
set_max_transition 0.10 [current_design]

# Max fanout
set_max_fanout 10 [current_design]

# Max capacitance
set_max_capacitance 0.30 [current_design]


# ----------------------------------------------------------
# 6. Output load (typical 45nm load = 20 fF)
# ----------------------------------------------------------
set_load 0.02 [get_ports {P[*]}]


############################################################
# END OF FILE
############################################################

