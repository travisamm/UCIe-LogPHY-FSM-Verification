+incdir+./if
+incdir+./agent
+incdir+./env
+incdir+./seq
+incdir+./tests

# LogPHY generated sources
-y ../elab/generatedVerilog/logphy 
+libext+.sv
../elab/generatedVerilog/logphy/SBInitSM.sv

# UVM Packages
./agent/logphy_agent_pkg.sv
./env/logphy_env_pkg.sv
./seq/logphy_seq_pkg.sv
./tests/logphy_test_pkg.sv

# Interfaces and Testbench Top
./if/logphy_if.sv
./tb/logphy_tb_top.sv
