`ifndef SBINIT_ENV_SV
`define SBINIT_ENV_SV

// ---------------------------------------------------------------------------
// sbinit_env
// ---------------------------------------------------------------------------
// Two active lane agents (requester + responder), a passive FSM-control
// monitor, a virtual sequencer, the scoreboard, and the coverage subscriber.
// All three monitors publish onto one common sbinit_event stream, which both
// the scoreboard and the coverage subscriber consume. cfg is propagated from
// the test down to the scoreboard via the config_db.
// ---------------------------------------------------------------------------

class sbinit_env extends uvm_env;
  `uvm_component_utils(sbinit_env)

  sbinit_req_agent          req_agent;
  sbinit_rsp_agent          rsp_agent;
  sbinit_ctrl_monitor       ctrl_monitor;
  sbinit_reset_monitor      reset_monitor;
  sbinit_reset_driver       reset_driver;
  sbinit_reset_sequencer    reset_seqr;
  sbinit_virtual_sequencer  vseqr;
  sbinit_scoreboard         scoreboard;
  sbinit_predictor          predictor;
  sbinit_coverage           coverage;
  sbinit_env_cfg            cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg))
      cfg = sbinit_env_cfg::type_id::create("cfg");
    uvm_config_db#(sbinit_env_cfg)::set(this, "scoreboard", "cfg", cfg);
    uvm_config_db#(sbinit_env_cfg)::set(this, "predictor",  "cfg", cfg);

    req_agent     = sbinit_req_agent::type_id::create("req_agent", this);
    rsp_agent     = sbinit_rsp_agent::type_id::create("rsp_agent", this);
    ctrl_monitor  = sbinit_ctrl_monitor::type_id::create("ctrl_monitor", this);
    reset_monitor = sbinit_reset_monitor::type_id::create("reset_monitor", this);
    reset_driver  = sbinit_reset_driver::type_id::create("reset_driver", this);
    reset_seqr    = sbinit_reset_sequencer::type_id::create("reset_seqr", this);
    vseqr         = sbinit_virtual_sequencer::type_id::create("vseqr", this);
    scoreboard    = sbinit_scoreboard::type_id::create("scoreboard", this);
    predictor     = sbinit_predictor::type_id::create("predictor", this);
    coverage      = sbinit_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vseqr.req_rx_seqr      = req_agent.rx_seqr;
    vseqr.req_txready_seqr = req_agent.txready_seqr;
    vseqr.rsp_rx_seqr      = rsp_agent.rx_seqr;
    vseqr.rsp_txready_seqr = rsp_agent.txready_seqr;
    vseqr.reset_seqr       = reset_seqr;

    // The reset driver pulls from the env-level reset sequencer.
    reset_driver.seq_item_port.connect(reset_seqr.seq_item_export);

    // Fan every event producer into the scoreboard, the reference-model
    // predictor, and the coverage subscriber.
    req_agent.monitor.ev_ap.connect(scoreboard.ev_export);
    rsp_agent.monitor.ev_ap.connect(scoreboard.ev_export);
    ctrl_monitor.ev_ap.connect(scoreboard.ev_export);
    reset_monitor.ev_ap.connect(scoreboard.ev_export);

    req_agent.monitor.ev_ap.connect(predictor.ev_export);
    rsp_agent.monitor.ev_ap.connect(predictor.ev_export);
    ctrl_monitor.ev_ap.connect(predictor.ev_export);
    reset_monitor.ev_ap.connect(predictor.ev_export);

    req_agent.monitor.ev_ap.connect(coverage.analysis_export);
    rsp_agent.monitor.ev_ap.connect(coverage.analysis_export);
    ctrl_monitor.ev_ap.connect(coverage.analysis_export);
    reset_monitor.ev_ap.connect(coverage.analysis_export);
  endfunction

endclass

`endif
