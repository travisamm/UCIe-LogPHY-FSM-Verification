class sbinit_coverage extends uvm_subscriber #(sbinit_req_transaction);
  `uvm_component_utils(sbinit_coverage)

  covergroup sbinit_cg with function sample(sbinit_req_transaction t);
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

  function void write(sbinit_req_transaction t);
    // Sample silently — per-event chatter buried the useful test/scoreboard
    // messages. Bump to UVM_DEBUG if you ever need to confirm sampling.
    sbinit_cg.sample(t);
    `uvm_info("COVERAGE", "sample", UVM_DEBUG)
  endfunction

  function void report_phase(uvm_phase phase);
    real cov;
    cov = sbinit_cg.get_inst_coverage();
    `uvm_info("COVERAGE",
              $sformatf("SBINIT functional coverage: %0.1f%%", cov),
              UVM_LOW)
  endfunction

endclass
