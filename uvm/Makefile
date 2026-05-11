XRUN     := /share/instsww/cadence/XCELIUM2509/tools/bin/xrun
XRUN_OPTS := -sv -uvm -access +rwc -timescale 1ns/1ps -64bit

.PHONY: sbinit sbinit_regress mbinit mbinit_regress ltsm mbtrain _mbtrain_run mbtrain_regress clean

SBTEST ?= test_sbinit_sanity
MBTEST ?= test_mbinit_sanity
MBTRAINTEST ?=
#MBTRAIN_TESTS ?= test_mbtrain_valvref test_mbtrain_datavref test_mbtrain_sanity
MBTRAIN_TESTS ?= test_mbtrain_valvref test_mbtrain_datavref test_mbtrain_sanity test_mbtrain_speedidle test_mbtrain_speedidle_retrain test_mbtrain_speedidle_error
MBTRAIN_LOG_DIR ?= run_logs/mbtrain
MBTRAIN_SUBMAKE ?= $(MAKE)

LTSTEST ?= test_ltsm_mbinit_repairval_trainerror

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
	  ./tb/mbinit_bind_exports.sv \
	  ./tb/mbinit_tb_top.sv \
	  +UVM_TESTNAME=$(MBTEST)

mbinit_regress:
	$(MAKE) mbinit MBTEST=test_mbinit_sanity
	$(MAKE) mbinit MBTEST=test_mbinit_param_mismatch
	$(MAKE) mbinit MBTEST=test_mbinit_param_only
	$(MAKE) mbinit MBTEST=test_mbinit_cal
	$(MAKE) mbinit MBTEST=test_mbinit_repairclk
	$(MAKE) mbinit MBTEST=test_mbinit_repairclk_unrep
	$(MAKE) mbinit MBTEST=test_mbinit_repairval_unrep

# ---- LinkTrainingSM (MBINIT + TRAINERROR SB) — sources under ./ltsm/ ----
ltsm:
	$(XRUN) $(XRUN_OPTS) \
	  +incdir+./ltsm/if +incdir+./ltsm/tb +incdir+./ltsm/tests \
	  -y ../elab/generatedVerilog/logphy +libext+.sv \
	  ../elab/generatedVerilog/logphy/LinkTrainingSM.sv \
	  ./ltsm/if/ltsm_obs_if.sv \
	  ./ltsm/tb/ltsm_fused_sb_partner.sv \
	  ./ltsm/tests/ltsm_test_pkg.sv \
	  ./ltsm/tb/ltsm_tb_top.sv \
	  +UVM_TESTNAME=$(LTSTEST)

# ---- MBTRAIN ----
mbtrain:
	@mkdir -p "$(MBTRAIN_LOG_DIR)"; \
	tests="$(if $(strip $(MBTRAINTEST)),$(strip $(MBTRAINTEST)),$(strip $(MBTRAIN_TESTS)))"; \
	results_file="$(MBTRAIN_LOG_DIR)/.results"; \
	error_re='^(UVM_ERROR|UVM_FATAL)[[:space:]]+[^:]|UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*|xrun:[[:space:]]+\*E|xmvlog:[[:space:]]+\*E|xmelab:[[:space:]]+\*E|\*E,'; \
	failed=0; \
	{ \
	  printf "MBTRAIN detailed results\n"; \
	  printf "Tests: %s\n\n" "$$tests"; \
	} > "$$results_file"; \
	printf "\nMBTRAIN results:\n"; \
	for test in $$tests; do \
	  log="$(MBTRAIN_LOG_DIR)/$$test.log"; \
	  if $(MBTRAIN_SUBMAKE) --no-print-directory _mbtrain_run MBTRAINTEST=$$test > "$$log" 2>&1; then \
	    sim_status=0; \
	  else \
	    sim_status=$$?; \
	  fi; \
	  if grep -Eq "$$error_re" "$$log"; then \
	    uvm_failure=1; \
	  else \
	    uvm_failure=0; \
	  fi; \
	  if [ $$sim_status -eq 0 ] && [ $$uvm_failure -eq 0 ]; then \
	    result=PASS; \
	  else \
	    result=FAIL; \
	    failed=1; \
	  fi; \
	  printf "  %-36s %s\n" "$$test" "$$result"; \
	  { \
	    printf "TEST: %s\n" "$$test"; \
	    printf "STATUS: %s\n" "$$result"; \
	    printf "LOG: %s\n" "$$log"; \
	    printf "SIM_EXIT_STATUS: %s\n" "$$sim_status"; \
	    if [ "$$result" = PASS ]; then \
	      printf "REASON: simulator exited 0 and no UVM_ERROR/UVM_FATAL lines were found\n"; \
	    else \
	      printf "REASON:"; \
	      if [ $$sim_status -ne 0 ]; then \
	        printf " simulator exited with status %s;" "$$sim_status"; \
	      fi; \
	      if [ $$uvm_failure -ne 0 ]; then \
	        printf " UVM_ERROR/UVM_FATAL present in log;"; \
	      fi; \
	      printf "\n"; \
	      error_lines="$$(grep -En "$$error_re" "$$log" | sed -n '1,80p')"; \
	      printf "ERROR_EXCERPT:\n"; \
	      if [ -n "$$error_lines" ]; then \
	        printf "%s\n" "$$error_lines"; \
	      else \
	        printf "<no UVM/Xcelium error regex matches; inspect full log for the nonzero exit cause>\n"; \
	      fi; \
	      printf "LOG_TAIL:\n"; \
	      tail -n 40 "$$log"; \
	    fi; \
	    printf "\n"; \
	  } >> "$$results_file"; \
	done; \
	printf "\nDetailed results: %s\n" "$$results_file"; \
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
