+incdir+./agent
+incdir+./agent/sbinit
+incdir+./agent/mbinit
+incdir+./agent/mbtrain
+incdir+./env/sbinit
+incdir+./env/mbinit
+incdir+./env/mbtrain
+incdir+./if/sbinit
+incdir+./if/mbinit
+incdir+./if/mbtrain
+incdir+./seq/sbinit
+incdir+./seq/mbinit
+incdir+./seq/mbtrain
+incdir+./tests/sbinit
+incdir+./tests/mbinit
+incdir+./tests/mbtrain

# LogPHY generated sources
-y ../elab/generatedVerilog/logphy
+libext+.sv
../elab/generatedVerilog/logphy/SBInitSM.sv

# ---- SBINIT UVM ----
./if/sbinit/sb_ctrl_if.sv
./if/sbinit/sb_req_if.sv
./if/sbinit/sb_rsp_if.sv
./agent/sbinit/sbinit_agent_pkg.sv
./env/sbinit/sbinit_env_pkg.sv
./seq/sbinit/sbinit_seq_pkg.sv
./tests/sbinit/sbinit_test_pkg.sv
./tb/sbinit/logphy_tb_top.sv

# ---- MBINIT UVM ----
# (separate target — not included in combined build yet)
../elab/generatedVerilog/logphy/MBInitSM.sv
../elab/generatedVerilog/logphy/MBInitRequester.sv
../elab/generatedVerilog/logphy/MBInitResponder.sv
./if/logphy_if.sv
./if/mbinit/mbinit_if.sv
./agent/logphy_agent_pkg.sv
./agent/mbinit/mbinit_agent_pkg.sv
./env/mbinit/mbinit_env_pkg.sv
./seq/mbinit/mbinit_seq_pkg.sv
./tests/mbinit/mbinit_test_pkg.sv
./tb/mbinit/mbinit_tb_top.sv

# ---- MBTRAIN UVM ----
../elab/generatedVerilog/logphy/MBTrainSM.sv
./if/mbtrain/mbtrain_if.sv
./agent/mbtrain/mbtrain_agent_pkg.sv
./env/mbtrain/mbtrain_env_pkg.sv
./seq/mbtrain/mbtrain_seq_pkg.sv
./tests/mbtrain/mbtrain_test_pkg.sv
./tb/mbtrain/mbtrain_tb_top.sv
