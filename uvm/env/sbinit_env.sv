`ifndef SBINIT_ENV_SV
`define SBINIT_ENV_SV

// ---------------------------------------------------------------------------
// Back-compat shim
// ---------------------------------------------------------------------------
// The legacy test bodies (logphy_sbinit_tests.sv) call:
//
//   seq = seq_sbinit_<flavor>::type_id::create("seq");
//   seq.start(env.agent.sequencer);
//
// where `seq` extends uvm_sequence #(logphy_transaction). The follow-on
// session rewrites those tests onto the new virtual sequencer. Until then
// this shim provides env.agent.sequencer plus a paired driver that mirrors
// the legacy single-agent behavior so the existing sequence bodies still
// run end-to-end. The new req/rsp drivers initialize their signals once and
// then block on get_next_item; they never contend with the shim driver.
// ---------------------------------------------------------------------------

class sbinit_legacy_driver extends uvm_driver #(logphy_transaction);
  `uvm_component_utils(sbinit_legacy_driver)

  virtual logphy_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual logphy_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"legacy shim driver could not get sbinit_req_vif for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.reset == 0);
    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(logphy_transaction t);
    vif.requesterSbLaneIo_tx_ready = t.tx_ready;
    vif.responderSbLaneIo_tx_ready = t.rsp_tx_ready;

    if (t.delay > 0) begin
      vif.requesterSbLaneIo_rx_valid = 0;
      vif.responderSbLaneIo_rx_valid = 0;
      repeat (t.delay) @(posedge vif.clock);
    end

    vif.fsmCtrl_start                  = t.start_fsm;
    vif.requesterSbLaneIo_rx_valid     = t.rx_valid;
    vif.requesterSbLaneIo_rx_bits_data = t.rx_data;
    vif.responderSbLaneIo_rx_valid     = t.rsp_rx_valid;
    vif.responderSbLaneIo_rx_bits_data = t.rsp_rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);

    vif.requesterSbLaneIo_rx_valid = 0;
    vif.responderSbLaneIo_rx_valid = 0;
  endtask
endclass

class sbinit_legacy_agent_shim extends uvm_component;
  `uvm_component_utils(sbinit_legacy_agent_shim)

  logphy_sequencer     sequencer;
  sbinit_legacy_driver driver;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = logphy_sequencer::type_id::create("sequencer", this);
    driver    = sbinit_legacy_driver::type_id::create("driver", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

// ---------------------------------------------------------------------------
// Env
// ---------------------------------------------------------------------------
class sbinit_env extends uvm_env;
  `uvm_component_utils(sbinit_env)

  sbinit_req_agent          req_agent;
  sbinit_rsp_agent          rsp_agent;
  sbinit_virtual_sequencer  vseqr;
  sbinit_scoreboard         scoreboard;
  sbinit_coverage           coverage;
  sbinit_env_cfg            cfg;

  // env.agent.sequencer entry point for legacy test bodies.
  sbinit_legacy_agent_shim  agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = sbinit_env_cfg::type_id::create("cfg");
    end
    uvm_config_db#(sbinit_env_cfg)::set(this, "scoreboard", "cfg", cfg);

    req_agent  = sbinit_req_agent::type_id::create("req_agent", this);
    rsp_agent  = sbinit_rsp_agent::type_id::create("rsp_agent", this);
    vseqr      = sbinit_virtual_sequencer::type_id::create("vseqr", this);
    scoreboard = sbinit_scoreboard::type_id::create("scoreboard", this);
    coverage   = sbinit_coverage::type_id::create("coverage", this);
    agent      = sbinit_legacy_agent_shim::type_id::create("agent", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vseqr.req_seqr = req_agent.sequencer;
    vseqr.rsp_seqr = rsp_agent.sequencer;
    req_agent.monitor.req_ap.connect(scoreboard.req_export);
    rsp_agent.monitor.rsp_ap.connect(scoreboard.rsp_export);
    req_agent.monitor.req_ap.connect(coverage.analysis_export);
  endfunction

endclass

`endif
