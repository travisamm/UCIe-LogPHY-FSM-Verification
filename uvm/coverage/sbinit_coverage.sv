class sbinit_coverage extends uvm_component;
  `uvm_component_utils(sbinit_coverage)

  uvm_analysis_imp #(logphy_transaction, sbinit_coverage) analysis_export;

  covergroup sbinit_cg with function sample(logphy_transaction t);

    cp_tx_valid: coverpoint t.tx_valid {
      bins sending = {1};
      bins idle    = {0};
    }
    cp_rx_valid: coverpoint t.rx_valid {
      bins receiving = {1};
      bins idle      = {0};
    }
    cp_sb_mode: coverpoint t.sbRxTxMode {
      bins functional = {1};
      bins pattern    = {0};
    }
    cp_fsm_error: coverpoint t.fsm_error {
      bins error    = {1};
      bins no_error = {0};
    }
    cp_fsm_done: coverpoint t.fsm_done {
bins done     = {1};
      bins not_done = {0};
    }
    cp_rsp_tx_valid: coverpoint t.rsp_tx_valid {
      bins sending = {1};
      bins idle    = {0};
    }
    cx_error_vs_done: cross cp_fsm_error, cp_fsm_done {
      bins normal_done  = binsof(cp_fsm_error.no_error) &&
                          binsof(cp_fsm_done.done);
      bins timeout_fail = binsof(cp_fsm_error.error) &&
                          binsof(cp_fsm_done.not_done);
    }
    cx_req_resp_done: cross cp_tx_valid, cp_rsp_tx_valid, cp_fsm_done {
      bins handshake_complete = binsof(cp_tx_valid.sending) &&
                                binsof(cp_rsp_tx_valid.sending) &&
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
