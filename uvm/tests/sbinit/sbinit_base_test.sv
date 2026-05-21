`ifndef SBINIT_BASE_TEST_SV
`define SBINIT_BASE_TEST_SV

class sbinit_base_test extends uvm_test;
  `uvm_component_utils(sbinit_base_test)

  sbinit_env     env;
  sbinit_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = sbinit_env_cfg::type_id::create("cfg");
    uvm_config_db#(sbinit_env_cfg)::set(this, "env", "cfg", cfg);
    env = sbinit_env::type_id::create("env", this);
  endfunction

  function sbinit_virtual_sequencer get_vseqr();
    return env.vseqr;
  endfunction

  // Wire a virtual sequence's sub-sequencer handles from env.vseqr. Tests call
  // this on their vseq before .start() so they don't repeat the wiring.
  function void connect_vseq(sbinit_base_vseq vseq);
    vseq.req_rx_seqr      = env.vseqr.req_rx_seqr;
    vseq.req_txready_seqr = env.vseqr.req_txready_seqr;
    vseq.rsp_rx_seqr      = env.vseqr.rsp_rx_seqr;
    vseq.rsp_txready_seqr = env.vseqr.rsp_txready_seqr;
  endfunction

endclass

`endif
