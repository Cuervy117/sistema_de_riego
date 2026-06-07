# Makefile to compile and simulate the Viego System VHDL project using GHDL

# Work directory for GHDL compiler files
WORK_DIR = work

# VHDL source and testbench files
SRC_FILES = hdl/spi_master.vhd \
            hdl/adc_controller.vhd \
            hdl/threshold_comparator.vhd \
            hdl/pwm_controller.vhd \
            hdl/fsm_central.vhd \
            hdl/sistema_riego_top.vhd

TB_FILES  = tb/tb_sistema_riego.vhd

# Top-level testbench entity
TB_ENTITY = tb_sistema_riego

# Waveform file output
VCD_FILE = wave.vcd

.PHONY: all compile run view clean

all: compile run

# Create work directory and import/analyze files
compile:
	mkdir -p $(WORK_DIR)
	ghdl -i --workdir=$(WORK_DIR) $(SRC_FILES) $(TB_FILES)
	ghdl -m --workdir=$(WORK_DIR) $(TB_ENTITY)

# Run the simulation and generate VCD waveform file
run:
	ghdl -r --workdir=$(WORK_DIR) $(TB_ENTITY) --vcd=$(VCD_FILE) --stop-time=350us

# Open GTKWave to view the waveform file
view: run
	gtkwave $(VCD_FILE) &

# Clean build and simulation outputs
clean:
	rm -rf $(WORK_DIR) $(VCD_FILE) e~$(TB_ENTITY).o
	ghdl --clean
