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

  // Push the per-lane SVA enable into the interfaces. Done after build (so
  // derived tests' build_phase has set the cfg flags) but before assertions
  // start mattering. The bound payload-stability checker reads stable_chk_en.
  function void start_of_simulation_phase(uvm_phase phase);
    virtual sb_req_if req_vif;
    virtual sb_rsp_if rsp_vif;
    super.start_of_simulation_phase(phase);
    if (uvm_config_db#(virtual sb_req_if)::get(this, "", "sbinit_req_vif", req_vif))
      req_vif.stable_chk_en = cfg.expect_req_tx_data_stable;
    if (uvm_config_db#(virtual sb_rsp_if)::get(this, "", "sbinit_rsp_vif", rsp_vif))
      rsp_vif.stable_chk_en = cfg.expect_rsp_tx_data_stable;
  endfunction

  // Note: sub-sequencer handles are no longer wired here. Virtual sequences
  // use the idiomatic p_sequencer pattern (`uvm_declare_p_sequencer in
  // sbinit_base_vseq) and grab their handles in pre_body when started on
  // env.vseqr.

endclass

`endif
