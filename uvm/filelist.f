+incdir+./if
+incdir+./agent
+incdir+./env
+incdir+./seq
+incdir+./tests

# LogPHY generated sources
-y ../elab/generatedVerilog/logphy
+libext+.sv
../elab/generatedVerilog/logphy/SBInitSM.sv

# ---- SBINIT UVM ----
./agent/logphy_agent_pkg.sv
./env/logphy_env_pkg.sv
./seq/logphy_seq_pkg.sv
./tests/logphy_test_pkg.sv
./if/logphy_if.sv
./tb/logphy_tb_top.sv

# ---- MBINIT UVM ----
# (separate target — not included in combined build yet)
../elab/generatedVerilog/logphy/MBInitSM.sv
../elab/generatedVerilog/logphy/MBInitRequester.sv
../elab/generatedVerilog/logphy/MBInitResponder.sv
./if/mbinit_if.sv
./agent/mbinit_agent_pkg.sv
./env/mbinit_env_pkg.sv
./seq/mbinit_seq_pkg.sv
./tests/mbinit_test_pkg.sv
./tb/mbinit_tb_top.sv

# ---- MBTRAIN UVM ----
../elab/generatedVerilog/logphy/MBTrainSM.sv
./if/mbtrain_if.sv
./agent/mbtrain_agent_pkg.sv
./env/mbtrain_env_pkg.sv
./seq/mbtrain_seq_pkg.sv
./tests/mbtrain_test_pkg.sv
./tb/mbtrain_tb_top.sv
