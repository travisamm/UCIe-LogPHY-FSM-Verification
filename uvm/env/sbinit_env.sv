`ifndef SBINIT_ENV_SV
`define SBINIT_ENV_SV

// ---------------------------------------------------------------------------
// sbinit_env
// ---------------------------------------------------------------------------
// Two active agents (requester + responder), a virtual sequencer, the
// scoreboard, and the coverage subscriber. cfg is propagated from the test
// down to the scoreboard via the config_db.
// ---------------------------------------------------------------------------

class sbinit_env extends uvm_env;
  `uvm_component_utils(sbinit_env)

  sbinit_req_agent          req_agent;
  sbinit_rsp_agent          rsp_agent;
  sbinit_virtual_sequencer  vseqr;
  sbinit_scoreboard         scoreboard;
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

    req_agent  = sbinit_req_agent::type_id::create("req_agent", this);
    rsp_agent  = sbinit_rsp_agent::type_id::create("rsp_agent", this);
    vseqr      = sbinit_virtual_sequencer::type_id::create("vseqr", this);
    scoreboard = sbinit_scoreboard::type_id::create("scoreboard", this);
    coverage   = sbinit_coverage::type_id::create("coverage", this);
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
