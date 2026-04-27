XRUN     := xrun
XRUN_OPTS := -sv -uvm -access +rwc -timescale 1ns/1ps -64bit

SBTEST ?= test_sbinit_sanity
MBTEST ?= test_mbinit_sanity

# ---- SBINIT ----
sbinit:
	$(XRUN) $(XRUN_OPTS) \
	  +incdir+./if +incdir+./agent +incdir+./env +incdir+./seq +incdir+./tests \
	  -y ../elab/generatedVerilog/logphy +libext+.sv \
	  ../elab/generatedVerilog/logphy/SBInitSM.sv \
	  ./if/logphy_if.sv \
	  ./agent/logphy_agent_pkg.sv \
	  ./env/logphy_env_pkg.sv \
	  ./seq/logphy_seq_pkg.sv \
	  ./tests/logphy_test_pkg.sv \
	  ./tb/logphy_tb_top.sv \
	  +UVM_TESTNAME=$(SBTEST)

sbinit_regress:
	$(MAKE) sbinit SBTEST=test_sbinit_sanity
	$(MAKE) sbinit SBTEST=test_sbinit_partner_not_ready
	$(MAKE) sbinit SBTEST=test_sbinit_early_req
	$(MAKE) sbinit SBTEST=test_sbinit_multiple_reqs

# ---- MBINIT ----
mbinit:
	$(XRUN) $(XRUN_OPTS) \
	  +incdir+./if +incdir+./agent +incdir+./env +incdir+./seq +incdir+./tests \
	  -y ../elab/generatedVerilog/logphy +libext+.sv \
	  ../elab/generatedVerilog/logphy/MBInitSM.sv \
	  ../elab/generatedVerilog/logphy/MBInitRequester.sv \
	  ../elab/generatedVerilog/logphy/MBInitResponder.sv \
	  ./if/mbinit_if.sv \
	  ./agent/logphy_agent_pkg.sv \
	  ./agent/mbinit_agent_pkg.sv \
	  ./env/mbinit_env_pkg.sv \
	  ./seq/mbinit_seq_pkg.sv \
	  ./tb/mbinit_tb_top.sv \
	  +UVM_TESTNAME=$(MBTEST)

mbinit_regress:
	$(MAKE) mbinit MBTEST=test_mbinit_sanity
	$(MAKE) mbinit MBTEST=test_mbinit_param_mismatch
	$(MAKE) mbinit MBTEST=test_mbinit_param_only

MBTRAINTEST ?= mbtrain_base_test

# ---- MBTRAIN ----
mbtrain:
	$(XRUN) $(XRUN_OPTS) \
	  +incdir+./if +incdir+./agent +incdir+./env +incdir+./seq +incdir+./tests \
	  -y ../elab/generatedVerilog/logphy +libext+.sv \
	  ../elab/generatedVerilog/logphy/MBTrainSM.sv \
	  ./if/mbtrain_if.sv \
	  ./agent/logphy_agent_pkg.sv \
	  ./agent/mbtrain_agent_pkg.sv \
	  ./env/mbtrain_env_pkg.sv \
	  ./seq/mbtrain_seq_pkg.sv \
	  ./tests/mbtrain_test_pkg.sv \
	  ./tb/mbtrain_tb_top.sv \
	  +UVM_TESTNAME=$(MBTRAINTEST)

mbtrain_regress:
	$(MAKE) mbtrain MBTRAINTEST=mbtrain_base_test

clean:
	rm -rf *.log *.history INCA_libs xcelium.d
