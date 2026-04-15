XRUN := xrun
XRUN_OPTS := -sv -uvm \
             -access +rwc \
             -timescale 1ps/1fs \
             -64bit \
             -permissive \
             -l xrun.log
             
UVM_TESTNAME ?= logphy_base_test

all: build run

build:
	$(XRUN) $(XRUN_OPTS) -compile -f filelist.f

run:
	$(XRUN) $(XRUN_OPTS) -f filelist.f +UVM_TESTNAME=$(UVM_TESTNAME)

clean:
	rm -rf *.log *.history INCA_libs xcelium.d
