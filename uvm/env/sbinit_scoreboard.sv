`ifndef SBINIT_SCOREBOARD_SV
`define SBINIT_SCOREBOARD_SV

class sbinit_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(sbinit_scoreboard)

  uvm_analysis_export  #(sbinit_req_transaction) req_export;
  uvm_analysis_export  #(sbinit_rsp_transaction) rsp_export;
  uvm_tlm_analysis_fifo #(sbinit_req_transaction) req_fifo;
  uvm_tlm_analysis_fifo #(sbinit_rsp_transaction) rsp_fifo;

  sbinit_env_cfg cfg;

  // SBINIT verification witnesses
  bit saw_clock_pattern;
  bit saw_rx_clock_pattern;
  bit saw_sbinit_done;
  bit sb_02_verified;
  bit sb_03_verified;
  bit sb_05_verified;
  bit sb_06_verified;
  bit saw_sbinit_done_req;
  bit saw_sbinit_done_resp;
  bit sb_07_verified;
  bit sb_08_verified;
  bit sb_09_verified;
  bit tb_sent_out_of_reset;
  bit tb_sent_early_done_req;
  bit dut_sent_early_done_resp;
  bit fsm_error_raised;
  bit prev_rsp_done_req_active;
  int unsigned sb_09_done_req_count;
  int unsigned sb_09_done_resp_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_export = new("req_export", this);
    rsp_export = new("rsp_export", this);
    req_fifo   = new("req_fifo",   this);
    rsp_fifo   = new("rsp_fifo",   this);

    if (!uvm_config_db#(sbinit_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_info("SBINIT_SB", "No cfg in config_db; using defaults", UVM_LOW)
      cfg = sbinit_env_cfg::type_id::create("cfg");
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    req_export.connect(req_fifo.analysis_export);
    rsp_export.connect(rsp_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    saw_clock_pattern        = 0;
    saw_rx_clock_pattern     = 0;
    saw_sbinit_done          = 0;
    sb_02_verified           = 0;
    sb_03_verified           = 0;
    sb_05_verified           = 0;
    sb_06_verified           = 0;
    saw_sbinit_done_req      = 0;
    saw_sbinit_done_resp     = 0;
    sb_07_verified           = 0;
    sb_08_verified           = 0;
    sb_09_verified           = 0;
    tb_sent_out_of_reset     = 0;
    tb_sent_early_done_req   = 0;
    dut_sent_early_done_resp = 0;
    fsm_error_raised         = 0;
    prev_rsp_done_req_active = 0;
    sb_09_done_req_count     = 0;
    sb_09_done_resp_count    = 0;

    fork
      forever begin
        sbinit_req_transaction req_tx;
        req_fifo.get(req_tx);
        process_req(req_tx);
      end
      forever begin
        sbinit_rsp_transaction rsp_tx;
        rsp_fifo.get(rsp_tx);
        process_rsp(rsp_tx);
      end
    join_none
  endtask

  task process_req(sbinit_req_transaction tx);
    // SB-01: 64-UI clock pattern on TX
    if (tx.tx_valid && (tx.tx_data == SBINIT_CLK_PATTERN_A  ||
                        tx.tx_data == SBINIT_CLK_PATTERN_A5 ||
                        tx.tx_data == SBINIT_CLK_PATTERN_5A ||
                        tx.tx_data == SBINIT_CLK_PATTERN_5)) begin
      if (!saw_clock_pattern) begin
        `uvm_info("SBINIT_SB", "SB-01 Verified: Detected 64-UI clock pattern on TX data", UVM_LOW)
        saw_clock_pattern = 1;
      end
    end else if (saw_clock_pattern && !sb_03_verified) begin
      // SB-03: after seeing clock pattern, the DUT stops sending it
      if (saw_rx_clock_pattern) begin
        `uvm_info("SBINIT_SB", "SB-03 Verified: DUT stopped sending clock pattern after pattern detection", UVM_LOW)
        sb_03_verified = 1;
      end
    end

    // SB-02 prerequisite: track that TB has driven its clock pattern on the requester RX
    if (tx.rx_valid && tx.rx_data == SBINIT_CLK_PATTERN_5) begin
      saw_rx_clock_pattern = 1;
    end

    // SB-02 / SB-05: mode transitions to functional sideband
    if (saw_clock_pattern && tx.sbRxTxMode == 1) begin
      if (saw_rx_clock_pattern && !sb_02_verified) begin
        `uvm_info("SBINIT_SB", "SB-02 Verified: DUT successfully sampled incoming SB data patterns with incoming clock", UVM_LOW)
        sb_02_verified = 1;
      end
      if (!sb_05_verified) begin
        `uvm_info("SBINIT_SB", "SB-05 Verified: Transitioned to functional sideband mode", UVM_LOW)
        sb_05_verified = 1;
      end
    end

    // Track TB sending {SBINIT Out of Reset} (on requester RX)
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR)) begin
      tb_sent_out_of_reset = 1;
    end

    // SB-06: DUT sends {SBINIT Out of Reset}
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_OUT_OF_RESET, SBINIT_SC_OOR)) begin
      if (!sb_06_verified) begin
        `uvm_info("SBINIT_SB", "SB-06 Verified: DUT sent {SBINIT Out of Reset} message", UVM_LOW)
        sb_06_verified = 1;
      end
    end

    // SB-07: DUT sends {SBINIT done req} on requester TX
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE)) begin
      if (!saw_sbinit_done_req) begin
        `uvm_info("SBINIT_SB", "SB-07 Partial: DUT sent {SBINIT done req}", UVM_LOW)
        saw_sbinit_done_req = 1;
      end
    end

    // SB-07: TB sends {SBINIT done resp} on requester RX
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE)) begin
      if (!saw_sbinit_done_resp) begin
        `uvm_info("SBINIT_SB", "SB-07 Partial: TB sent {SBINIT done resp}", UVM_LOW)
        saw_sbinit_done_resp = 1;
      end
    end

    // Track FSM error (currently tied to 0 by RTL)
    if (tx.fsm_error) begin
      `uvm_info("SBINIT_SB", "SB-04/FSM Error: Module raised timeout/error flag", UVM_LOW)
      fsm_error_raised = 1;
    end

    // FSM done — gate SB-07/SB-08 verification on exit
    if (tx.fsm_done) begin
      if (saw_sbinit_done_req && saw_sbinit_done_resp && !sb_07_verified) begin
        `uvm_info("SBINIT_SB", "SB-07 Verified: DUT sent {SBINIT done req} and waited for {SBINIT done resp} before exiting", UVM_LOW)
        sb_07_verified = 1;
      end

      if (tb_sent_early_done_req && !dut_sent_early_done_resp && !sb_08_verified) begin
        `uvm_info("SBINIT_SB", "SB-08 Verified: DUT correctly ignored early {SBINIT done req}", UVM_LOW)
        sb_08_verified = 1;
      end

      if (!saw_sbinit_done) begin
        `uvm_info("SBINIT_SB", "FSM Done: SBINIT sequence completed", UVM_LOW)
      end
      saw_sbinit_done = 1;
    end
  endtask

  task process_rsp(sbinit_rsp_transaction tx);
    // Track TB sending early {SBINIT done req} on responder RX (before Out of Reset went out)
    if (tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE)) begin
      if (!tb_sent_out_of_reset) begin
        tb_sent_early_done_req = 1;
      end
    end

    // SB-09: count edge-detected {SBINIT done req} bursts on responder RX after Out of Reset
    if (tb_sent_out_of_reset &&
        tx.rx_valid &&
        is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE) &&
        !prev_rsp_done_req_active) begin
      sb_09_done_req_count++;
      `uvm_info("SBINIT_SB",
                $sformatf("SB-09 Track: TB sent responder {SBINIT done req} count=%0d", sb_09_done_req_count),
                UVM_LOW)
    end
    prev_rsp_done_req_active = tb_sent_out_of_reset &&
                               tx.rx_valid &&
                               is_sbinit_msg(tx.rx_data, SBINIT_MC_DONE_REQ, SBINIT_SC_DONE);

    // SB-08: DUT must NOT emit {SBINIT done resp} before TB has sent Out of Reset
    if (tx.tx_valid &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE)) begin
      if (tb_sent_early_done_req && !tb_sent_out_of_reset) begin
        `uvm_error("SBINIT_SB", "SB-08 FAILED: DUT sent {SBINIT done resp} early!")
        dut_sent_early_done_resp = 1;
      end
    end

    // SB-09: count accepted {SBINIT done resp} from DUT once multiple done reqs were sent
    if (sb_09_done_req_count > 1 &&
        tx.tx_valid && tx.tx_ready &&
        is_sbinit_msg(tx.tx_data, SBINIT_MC_DONE_RESP, SBINIT_SC_DONE)) begin
      sb_09_done_resp_count++;
      `uvm_info("SBINIT_SB",
                $sformatf("SB-09 Track: DUT accepted responder {SBINIT done resp} count=%0d", sb_09_done_resp_count),
                UVM_LOW)
    end
  endtask

  function void check_phase(uvm_phase phase);
    // Derive SB-09 verification from collected counters
    if (sb_09_done_req_count > 1) begin
      if (!saw_sbinit_done) begin
        `uvm_error("SBINIT_SB", "SB-09 FAILED: FSM did not complete after multiple responder {SBINIT done req} messages")
      end else if (sb_09_done_resp_count == 1) begin
        `uvm_info("SBINIT_SB", "SB-09 Verified: DUT collapsed multiple {SBINIT done req} messages into one {SBINIT done resp}", UVM_LOW)
        sb_09_verified = 1;
      end else begin
        `uvm_error("SBINIT_SB",
                   $sformatf("SB-09 FAILED: saw %0d responder done reqs and %0d accepted done resps",
                             sb_09_done_req_count, sb_09_done_resp_count))
      end
    end

    if (cfg.expect_sb01_clock_pattern && !saw_clock_pattern)
      `uvm_error("SBINIT_SB", "SB-01 FAILED: DUT never transmitted 64-UI clock pattern")
    if (cfg.expect_sb02_rx_sampling && !sb_02_verified)
      `uvm_error("SBINIT_SB", "SB-02 FAILED: sbRxTxMode never went to 1 after incoming pattern")
    if (cfg.expect_sb03_stop_on_detect && !sb_03_verified)
      `uvm_error("SBINIT_SB", "SB-03 FAILED: DUT did not stop transmitting after detection")
    if (cfg.expect_sb05_mode_transition && !sb_05_verified)
      `uvm_error("SBINIT_SB", "SB-05 FAILED: sbRxTxMode never transitioned to functional sideband")
    if (cfg.expect_sb06_out_of_reset && !sb_06_verified)
      `uvm_error("SBINIT_SB", "SB-06 FAILED: DUT never sent {SBINIT Out of Reset} message")
    if (cfg.expect_sb07_done_handshake && !sb_07_verified)
      `uvm_error("SBINIT_SB", "SB-07 FAILED: done req/resp handshake not completed before exit")
    if (cfg.expect_sb08_ignore_early && !sb_08_verified)
      `uvm_error("SBINIT_SB", "SB-08 FAILED: DUT did not correctly ignore early {SBINIT done req}")
    if (cfg.expect_sb09_collapse_reqs && !sb_09_verified)
      `uvm_error("SBINIT_SB", "SB-09 FAILED: DUT did not collapse multiple {SBINIT done req} to one resp")
    if (cfg.expect_fsm_done && !saw_sbinit_done)
      `uvm_error("SBINIT_SB", "SBINIT FAILED: fsmCtrl_done never asserted")
    if (cfg.expect_fsm_error && !fsm_error_raised)
      `uvm_error("SBINIT_SB", "Expected fsmCtrl_error but it never asserted")
    if (!cfg.expect_fsm_error && fsm_error_raised)
      `uvm_error("SBINIT_SB", "Unexpected fsmCtrl_error on success-path test")

    `uvm_info("SBINIT_SB",
              $sformatf("Final stats: saw_clock_pattern=%0b, sb_02=%0b, sb_03=%0b, sb_05=%0b, sb_06=%0b, sb_07=%0b, sb_08=%0b, sb_09=%0b, sb_09_req_count=%0d, sb_09_resp_count=%0d, fsm_done=%0b, error=%0b",
                        saw_clock_pattern, sb_02_verified, sb_03_verified, sb_05_verified, sb_06_verified,
                        sb_07_verified, sb_08_verified, sb_09_verified,
                        sb_09_done_req_count, sb_09_done_resp_count, saw_sbinit_done, fsm_error_raised),
              UVM_LOW)
  endfunction

endclass

`endif
