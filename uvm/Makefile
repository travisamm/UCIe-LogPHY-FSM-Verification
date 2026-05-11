XRUN     := /share/instsww/cadence/XCELIUM2509/tools/bin/xrun
XRUN_OPTS := -sv -uvm -access +rwc -timescale 1ns/1ps -64bit

SBTEST ?= test_sbinit_sanity
MBTEST ?= test_mbinit_sanity
MBTRAINTEST ?=
MBTRAIN_TESTS ?= test_mbtrain_valvref test_mbtrain_datavref test_mbtrain_sanity
MBTRAIN_LOG_DIR ?= run_logs/mbtrain
MBTRAIN_SUBMAKE ?= $(MAKE)

.PHONY: sbinit sbinit_regress mbinit mbinit_regress mbtrain _mbtrain_run mbtrain_regress clean

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
	  ./if/logphy_if.sv \
	  ./if/mbinit_if.sv \
	  ./agent/logphy_agent_pkg.sv \
	  ./agent/mbinit_agent_pkg.sv \
	  ./env/mbinit_env_pkg.sv \
	  ./seq/mbinit_seq_pkg.sv \
	  ./tests/mbinit_test_pkg.sv \
	  ./tb/mbinit_tb_top.sv \
	  +UVM_TESTNAME=$(MBTEST)

mbinit_regress:
	$(MAKE) mbinit MBTEST=test_mbinit_sanity
	$(MAKE) mbinit MBTEST=test_mbinit_param_mismatch
	$(MAKE) mbinit MBTEST=test_mbinit_param_only
	$(MAKE) mbinit MBTEST=test_mbinit_repairclk_unrep
	$(MAKE) mbinit MBTEST=test_mbinit_repairval_unrep

# ---- MBTRAIN ----
mbtrain:
	@mkdir -p "$(MBTRAIN_LOG_DIR)"; \
	tests="$(if $(strip $(MBTRAINTEST)),$(strip $(MBTRAINTEST)),$(strip $(MBTRAIN_TESTS)))"; \
	results_file="$(MBTRAIN_LOG_DIR)/.results"; \
	failed=0; \
	: > "$$results_file"; \
	for test in $$tests; do \
	  log="$(MBTRAIN_LOG_DIR)/$$test.log"; \
	  printf "Running %s...\n" "$$test"; \
	  if $(MBTRAIN_SUBMAKE) --no-print-directory _mbtrain_run MBTRAINTEST=$$test > "$$log" 2>&1; then \
	    sim_status=0; \
	  else \
	    sim_status=$$?; \
	  fi; \
	  if [ $$sim_status -eq 0 ] && ! grep -Eq '^(UVM_ERROR|UVM_FATAL)([^:]*@|[[:space:]]*:[[:space:]]*[1-9])' "$$log"; then \
	    result=PASS; \
	  else \
	    result=FAIL; \
	    failed=1; \
	  fi; \
	  printf "  %-36s %s\n" "$$test" "$$result" >> "$$results_file"; \
	done; \
	printf "\nMBTRAIN results:\n"; \
	cat "$$results_file"; \
	printf "\nLogs: %s\n" "$(MBTRAIN_LOG_DIR)"; \
	if [ $$failed -ne 0 ]; then \
	  printf "One or more MBTRAIN tests failed; see the per-test logs above.\n"; \
	fi; \
	exit $$failed

_mbtrain_run:
	$(XRUN) $(XRUN_OPTS) \
	  +incdir+./if +incdir+./agent +incdir+./env +incdir+./seq +incdir+./tests \
	  -y ../elab/generatedVerilog/logphy +libext+.sv \
	  ../elab/generatedVerilog/logphy/MBTrainSM.sv \
	  ./if/logphy_if.sv \
	  ./if/mbtrain_if.sv \
	  ./agent/logphy_agent_pkg.sv \
	  ./agent/mbtrain_agent_pkg.sv \
	  ./env/mbtrain_env_pkg.sv \
	  ./seq/mbtrain_seq_pkg.sv \
	  ./tests/mbtrain_test_pkg.sv \
	  ./tb/mbtrain_tb_top.sv \
	  +UVM_TESTNAME=$(MBTRAINTEST)

mbtrain_regress: mbtrain

clean:
	rm -rf *.log *.history INCA_libs xcelium.d run_logs
