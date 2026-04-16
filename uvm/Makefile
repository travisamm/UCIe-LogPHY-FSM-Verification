XRUN := xrun
XRUN_OPTS := -sv -uvm \
             -access +rwc \
             -timescale 1ns/1ps \
             -64bit \
             
TEST ?= logphy_base_test

all: build run

build:
	$(XRUN) $(XRUN_OPTS) -compile -f filelist.f

run:
	$(XRUN) $(XRUN_OPTS) -f filelist.f +UVM_TESTNAME=$(TEST)

clean:
	rm -rf *.log *.history INCA_libs xcelium.d
