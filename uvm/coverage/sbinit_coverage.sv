class sbinit_coverage extends uvm_component;
  `uvm_component_utils(sbinit_coverage)

  uvm_analysis_imp #(logphy_transaction, sbinit_coverage) analysis_export;

  covergroup sbinit_cg with function sample(logphy_transaction t);
    option.per_instance = 1;
    option.name = "sbinit_cg";
    option.cross_auto_bin_max = 0;

    // SB-01/SB-02: requester and partner SB lane TX activity
    cp_tx_valid: coverpoint t.tx_valid {
      bins sending = {1};
      bins idle    = {0};
    }
    cp_rx_valid: coverpoint t.rx_valid {
      bins receiving = {1};
      bins idle      = {0};
    }

    // SB-05: mode switches from pattern (0) to functional (1) after detection
    cp_sb_mode: coverpoint t.sbRxTxMode {
      bins functional = {1};
      bins pattern    = {0};
    }

    // SB-04: io_fsmCtrl_error is not exposed as a port by SBInitSM (hardcoded 0 in RTL).
    // ignore_bins excludes error=1 until the RTL exports the port.
    cp_fsm_error: coverpoint t.fsm_error {
      ignore_bins error_rtl_na = {1};
      bins no_error = {0};
    }

    cp_fsm_done: coverpoint t.fsm_done {
      bins done     = {1};
      bins not_done = {0};
    }

    // SB-07: responder SB lane TX (done resp)
    cp_rsp_tx_valid: coverpoint t.rsp_tx_valid {
      bins sending = {1};
      bins idle    = {0};
    }

    // SB-05/SB-07: normal exit — no_error+done.
    // timeout_fail (error+not_done) omitted: error port not exposed by RTL.
    cx_error_vs_done: cross cp_fsm_error, cp_fsm_done {
      bins normal_done = binsof(cp_fsm_error.no_error) &&
                         binsof(cp_fsm_done.done);
    }


  endgroup : sbinit_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    sbinit_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(logphy_transaction t);
    sbinit_cg.sample(t);
    `uvm_info("COVERAGE", "Coverage sampled!", UVM_LOW)
  endfunction

endclass
