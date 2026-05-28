`ifndef MBINIT_ENV_SV
`define MBINIT_ENV_SV

// ---------------------------------------------------------------------------
// mbinit_env  (Pass 3)
// ---------------------------------------------------------------------------
// Legacy facade + new split drive path coexisting:
//   * agent (mbinit_agent): legacy sequencer + driver + monitor. The driver is
//     factory-overridden to mbinit_legacy_adapter, so env.agent.driver is still
//     a mbinit_driver (the rm02/rm07/rm05 tests' $cast + flag-set keep working)
//     but it decomposes each mbinit_transaction onto the new split sequencers
//     instead of driving the monolithic vif.
//   * new split drive components drive the split interfaces (which tb_top
//     bridges to the DUT): requester/responder RX drivers, FSM-control driver,
//     and autonomous cal/pattern-writer/pattern-reader/point-test stubs.
//   * scoreboard + coverage are UNCHANGED and still fed by the legacy monitor
//     (which reads the monolithic vif). Event-producing monitors are Pass 4.
//
// TODO(pass 8): once tests run on env.vseqr, retire the legacy agent + adapter.
// ---------------------------------------------------------------------------
class mbinit_env extends uvm_env;
  `uvm_component_utils(mbinit_env)

  // Legacy facade
  mbinit_agent      agent;
  mbinit_scoreboard scoreboard;
  mbinit_coverage   coverage;

  // New split drive path (Pass 3)
  mbinit_req_rx_driver     req_rx_driver;
  mbinit_rx_sequencer      req_rx_seqr;
  mbinit_rsp_rx_driver     rsp_rx_driver;
  mbinit_rx_sequencer      rsp_rx_seqr;
  mbinit_ctrl_driver       ctrl_driver;
  mbinit_ctrl_sequencer    ctrl_seqr;
  mbinit_cal_stub          cal_stub;
  mbinit_pw_stub           pw_stub;
  mbinit_pr_stub           pr_stub;
  mbinit_pttest_req_stub   pttest_req_stub;
  mbinit_pttest_rsp_stub   pttest_rsp_stub;
  mbinit_service_cfg       svc_cfg;
  mbinit_virtual_sequencer vseqr;

  // Pass 4: event-producing monitors + passive audit subscriber (shadow stream;
  // legacy monitor/scoreboard/coverage stay authoritative).
  mbinit_req_monitor        evt_req_mon;
  mbinit_rsp_monitor        evt_rsp_mon;
  mbinit_ctrl_monitor       evt_ctrl_mon;
  mbinit_reset_monitor      evt_reset_mon;
  mbinit_cal_monitor        evt_cal_mon;
  mbinit_pw_monitor         evt_pw_mon;
  mbinit_pr_monitor         evt_pr_mon;
  mbinit_pttest_req_monitor evt_pttest_req_mon;
  mbinit_pttest_rsp_monitor evt_pttest_rsp_mon;
  mbinit_lane_ctrl_monitor  evt_lane_ctrl_mon;
  mbinit_event_audit        evt_audit;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Route the legacy agent's driver to the adapter (must precede agent build).
    mbinit_driver::type_id::set_type_override(mbinit_legacy_adapter::get_type());

    agent      = mbinit_agent::type_id::create("agent", this);
    scoreboard = mbinit_scoreboard::type_id::create("scoreboard", this);
    coverage   = mbinit_coverage::type_id::create("coverage", this);

    // Shared service policy, published for the service stubs.
    svc_cfg = mbinit_service_cfg::type_id::create("svc_cfg");
    uvm_config_db#(mbinit_service_cfg)::set(this, "*", "mbinit_svc_cfg", svc_cfg);

    // New split drive components.
    req_rx_driver   = mbinit_req_rx_driver::type_id::create("req_rx_driver", this);
    req_rx_seqr     = mbinit_rx_sequencer::type_id::create("req_rx_seqr", this);
    rsp_rx_driver   = mbinit_rsp_rx_driver::type_id::create("rsp_rx_driver", this);
    rsp_rx_seqr     = mbinit_rx_sequencer::type_id::create("rsp_rx_seqr", this);
    ctrl_driver     = mbinit_ctrl_driver::type_id::create("ctrl_driver", this);
    ctrl_seqr       = mbinit_ctrl_sequencer::type_id::create("ctrl_seqr", this);
    cal_stub        = mbinit_cal_stub::type_id::create("cal_stub", this);
    pw_stub         = mbinit_pw_stub::type_id::create("pw_stub", this);
    pr_stub         = mbinit_pr_stub::type_id::create("pr_stub", this);
    pttest_req_stub = mbinit_pttest_req_stub::type_id::create("pttest_req_stub", this);
    pttest_rsp_stub = mbinit_pttest_rsp_stub::type_id::create("pttest_rsp_stub", this);
    vseqr           = mbinit_virtual_sequencer::type_id::create("vseqr", this);

    // Pass 4 event producers + audit subscriber.
    evt_req_mon         = mbinit_req_monitor::type_id::create("evt_req_mon", this);
    evt_rsp_mon         = mbinit_rsp_monitor::type_id::create("evt_rsp_mon", this);
    evt_ctrl_mon        = mbinit_ctrl_monitor::type_id::create("evt_ctrl_mon", this);
    evt_reset_mon       = mbinit_reset_monitor::type_id::create("evt_reset_mon", this);
    evt_cal_mon         = mbinit_cal_monitor::type_id::create("evt_cal_mon", this);
    evt_pw_mon          = mbinit_pw_monitor::type_id::create("evt_pw_mon", this);
    evt_pr_mon          = mbinit_pr_monitor::type_id::create("evt_pr_mon", this);
    evt_pttest_req_mon  = mbinit_pttest_req_monitor::type_id::create("evt_pttest_req_mon", this);
    evt_pttest_rsp_mon  = mbinit_pttest_rsp_monitor::type_id::create("evt_pttest_rsp_mon", this);
    evt_lane_ctrl_mon   = mbinit_lane_ctrl_monitor::type_id::create("evt_lane_ctrl_mon", this);
    evt_audit           = mbinit_event_audit::type_id::create("evt_audit", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    mbinit_legacy_adapter ad;
    super.connect_phase(phase);

    // Legacy monitor feeds the (unchanged) scoreboard + coverage.
    agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
    agent.monitor.item_collected_port.connect(coverage.analysis_export);

    // New drivers <-> their sequencers.
    req_rx_driver.seq_item_port.connect(req_rx_seqr.seq_item_export);
    rsp_rx_driver.seq_item_port.connect(rsp_rx_seqr.seq_item_export);
    ctrl_driver.seq_item_port.connect(ctrl_seqr.seq_item_export);

    // Virtual sequencer handles (for Pass 8 vseqs).
    vseqr.req_rx_seqr = req_rx_seqr;
    vseqr.rsp_rx_seqr = rsp_rx_seqr;
    vseqr.ctrl_seqr   = ctrl_seqr;

    // Wire the legacy adapter to the split sequencers + service policy.
    if (!$cast(ad, agent.driver))
      `uvm_fatal("MBINIT_ENV",
                 "agent.driver is not mbinit_legacy_adapter (factory override failed?)")
    ad.req_rx_seqr = req_rx_seqr;
    ad.rsp_rx_seqr = rsp_rx_seqr;
    ad.ctrl_seqr   = ctrl_seqr;
    ad.svc_cfg     = svc_cfg;

    // Pass 4: fan all event producers into the single audit subscriber.
    evt_req_mon.ev_ap.connect       (evt_audit.analysis_export);
    evt_rsp_mon.ev_ap.connect       (evt_audit.analysis_export);
    evt_ctrl_mon.ev_ap.connect      (evt_audit.analysis_export);
    evt_reset_mon.ev_ap.connect     (evt_audit.analysis_export);
    evt_cal_mon.ev_ap.connect       (evt_audit.analysis_export);
    evt_pw_mon.ev_ap.connect        (evt_audit.analysis_export);
    evt_pr_mon.ev_ap.connect        (evt_audit.analysis_export);
    evt_pttest_req_mon.ev_ap.connect(evt_audit.analysis_export);
    evt_pttest_rsp_mon.ev_ap.connect(evt_audit.analysis_export);
    evt_lane_ctrl_mon.ev_ap.connect (evt_audit.analysis_export);
  endfunction

endclass
`endif
