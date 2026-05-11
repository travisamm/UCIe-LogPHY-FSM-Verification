`ifndef SBINIT_COVERAGE_SV
`define SBINIT_COVERAGE_SV

class sbinit_coverage extends uvm_component;
  `uvm_component_utils(sbinit_coverage)

  uvm_analysis_imp #(sbinit_transaction, sbinit_coverage) analysis_export;

  covergroup sbinit_cg;

    cp_clock_pattern_sent: coverpoint dut.sb_tx_clk_pattern_sent {
      bins sent = {1};
    }
    cp_low_pattern_sent: coverpoint dut.sb_tx_low_pattern_sent {
      bins sent = {1};
    }
    cp_pattern_sampled: coverpoint dut.sb_rx_pattern_sampled {
      bins sampled = {1};
    }
    cp_pattern_detected: coverpoint dut.sb_pattern_detected {
      bins detected     = {1};
      bins not_detected = {0};
    }
    cp_tx_stopped_after_detection: coverpoint dut.sb_tx_stopped {
      bins stopped = {1};
    }
    cp_timeout: coverpoint dut.sb_timeout {
      bins timed_out  = {1};
      bins no_timeout = {0};
    }
    cp_fsm_state: coverpoint dut.sbinit_fsm_state {
      bins IDLE       = {SBINIT_IDLE};
      bins SEND       = {SBINIT_SEND};
      bins DETECT     = {SBINIT_DETECT};
      bins FUNCTIONAL = {SBINIT_FUNCTIONAL};
      bins DONE_WAIT  = {SBINIT_DONE_WAIT};
      bins TRAINERROR = {SBINIT_TRAINERROR};
    }
    cx_timeout_trainerror: cross cp_timeout, cp_fsm_state {
      bins timeout_leads_to_error = binsof(cp_timeout.timed_out) &&
                                    binsof(cp_fsm_state.TRAINERROR);
    }
    cp_sb_tx_enabled: coverpoint dut.sb_tx_enabled {
      bins enabled = {1};
    }
    cp_sb_rx_enabled: coverpoint dut.sb_rx_enabled {
      bins enabled = {1};
    }
    cp_out_of_reset_msg_sent: coverpoint dut.sb_out_of_reset_msg_count {
      bins single_send = {[1:1]};
      bins multi_send  = {[2:$]};
    }
    cp_partner_ready: coverpoint dut.sb_partner_ready {
      bins ready_immediately = {1};
      bins ready_delayed     = {0};
    }
    cx_delayed_partner: cross cp_partner_ready, cp_out_of_reset_msg_sent {
      bins delayed_causes_multi = binsof(cp_partner_ready.ready_delayed) &&
                                  binsof(cp_out_of_reset_msg_sent.multi_send);
    }
    cp_done_req_sent: coverpoint dut.sb_done_req_sent {
      bins sent = {1};
    }
    cp_done_resp_received: coverpoint dut.sb_done_resp_received {
      bins received = {1};
    }
    cx_req_then_resp: cross cp_done_req_sent, cp_done_resp_received {
      bins req_before_resp = binsof(cp_done_req_sent.sent) &&
                             binsof(cp_done_resp_received.received);
    }
    cp_early_req_received: coverpoint dut.sb_early_req_received {
      bins received = {1};
      bins not_seen = {0};
    }
    cp_early_req_ignored: coverpoint dut.sb_early_req_ignored {
      bins ignored = {1};
    }
    cx_early_req_ignored: cross cp_early_req_received, cp_early_req_ignored {
      bins early_req_properly_ignored = binsof(cp_early_req_received.received) &&
                                        binsof(cp_early_req_ignored.ignored);
    }
    cp_req_count: coverpoint dut.sb_done_req_count {
      bins one_req      = {1};
      bins multiple_req = {[2:$]};
    }
    cp_resp_count: coverpoint dut.sb_done_resp_count {
      bins single_resp = {1};
    }
    cx_req_collapse: cross cp_req_count, cp_resp_count {
      bins multi_req_single_resp = binsof(cp_req_count.multiple_req) &&
                                   binsof(cp_resp_count.single_resp);
    }

  endgroup : sbinit_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    sbinit_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(sbinit_transaction t);
    sbinit_cg.sample();
    `uvm_info("COVERAGE", "Coverage sampled!", UVM_LOW)
  endfunction

endclass

`endif
