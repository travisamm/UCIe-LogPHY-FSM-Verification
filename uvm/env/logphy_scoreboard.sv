`ifndef LOGPHY_SCOREBOARD_SV
`define LOGPHY_SCOREBOARD_SV

class logphy_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(logphy_scoreboard)

  uvm_analysis_export #(logphy_transaction) item_collected_export;
  uvm_tlm_analysis_fifo #(logphy_transaction) item_collected_fifo;

  // Variables to track SBINIT checks
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
  bit tb_sent_out_of_reset;
  bit tb_sent_early_done_req;
  bit dut_sent_early_done_resp;
  bit fsm_error_raised;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_export = new("item_collected_export", this);
    item_collected_fifo = new("item_collected_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    item_collected_export.connect(item_collected_fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    logphy_transaction tx;
    saw_clock_pattern = 0;
    saw_rx_clock_pattern = 0;
    saw_sbinit_done = 0;
    sb_02_verified = 0;
    sb_03_verified = 0;
    sb_05_verified = 0;
    sb_06_verified = 0;
    saw_sbinit_done_req = 0;
    saw_sbinit_done_resp = 0;
    sb_07_verified = 0;
    sb_08_verified = 0;
    tb_sent_out_of_reset = 0;
    tb_sent_early_done_req = 0;
    dut_sent_early_done_resp = 0;
    fsm_error_raised = 0;

    forever begin
      item_collected_fifo.get(tx);
      
      // SB-01 Check: 64-UI clock pattern followed by 32-UI low on TX
      if (tx.tx_valid && (tx.tx_data == 128'hAAAAAAAAAAAAAAAA_00000000_00000000 || 
                          tx.tx_data == 128'h00000000_00000000_AAAAAAAAAAAAAAAA ||
                          tx.tx_data == 128'h55555555_55555555_00000000_00000000 ||
                          tx.tx_data == 128'h00000000_00000000_55555555_55555555)) begin
        if (!saw_clock_pattern) begin
           `uvm_info("SCOREBOARD", "SB-01 Verified: Detected 64-UI clock pattern on TX data", UVM_LOW)
           saw_clock_pattern = 1;
        end
      end else if (saw_clock_pattern && !sb_03_verified) begin
        // If we saw the clock pattern previously, and now we see something else on TX,
        // (either tx_valid dropped to 0 or tx_data changed to a non-clock pattern),
        // and we had provided an RX clock pattern, it means the DUT stopped sending the pattern upon detection.
        if (saw_rx_clock_pattern) begin
           `uvm_info("SCOREBOARD", "SB-03 Verified: DUT stopped sending clock pattern after pattern detection", UVM_LOW)
           sb_03_verified = 1;
        end
      end

      // Track incoming SB-02 RX clock pattern sent from the TB to the DUT
      if (tx.rx_valid && tx.rx_data == 128'h00000000_00000000_55555555_55555555) begin
        if (!saw_rx_clock_pattern) begin
           saw_rx_clock_pattern = 1;
        end
      end

      // Check if RX/TX mode shifts to functional sideband (SB-05)
      if (saw_clock_pattern && tx.sbRxTxMode == 1) begin
         if (saw_rx_clock_pattern && !sb_02_verified) begin
            `uvm_info("SCOREBOARD", "SB-02 Verified: DUT successfully sampled incoming SB data patterns with incoming clock", UVM_LOW)
            sb_02_verified = 1;
         end
         if (!sb_05_verified) begin
            `uvm_info("SCOREBOARD", "SB-05 Verified: Transitioned to functional sideband mode", UVM_LOW)
            sb_05_verified = 1;
         end
      end

      // Track TB's Out of Reset (msgCode 0x91)
      if (tx.rx_valid && tx.rx_data[4:0] == 5'h12 && tx.rx_data[21:14] == 8'h91) begin
         tb_sent_out_of_reset = 1;
      end

      // SB-06 Check: Track if DUT sends {SBINIT Out of Reset} (msgCode 0x91)
      if (tx.tx_valid && tx.tx_data[4:0] == 5'h12 && tx.tx_data[21:14] == 8'h91 && tx.tx_data[39:32] == 8'h00) begin
         if (!sb_06_verified) begin
            `uvm_info("SCOREBOARD", "SB-06 Verified: DUT sent {SBINIT Out of Reset} message", UVM_LOW)
            sb_06_verified = 1;
         end
      end

      // Track TB sending EARLY {SBINIT done req} (msgCode 0x95) on responder RX
      if (tx.rsp_rx_valid && tx.rsp_rx_data[4:0] == 5'h12 && tx.rsp_rx_data[21:14] == 8'h95) begin
         if (!tb_sent_out_of_reset) begin
            tb_sent_early_done_req = 1;
         end
      end

      // Track DUT incorrectly sending {SBINIT done resp} (msgCode 0x9A) early
      if (tx.rsp_tx_valid && tx.rsp_tx_data[4:0] == 5'h12 && tx.rsp_tx_data[21:14] == 8'h9A) begin
         if (tb_sent_early_done_req && !tb_sent_out_of_reset) begin
            `uvm_error("SCOREBOARD", "SB-08 FAILED: DUT sent {SBINIT done resp} early!")
            dut_sent_early_done_resp = 1;
         end
      end

      // SB-07 Check: Track if we saw done req from DUT
      // Check opcode=5'h12, msgCode=8'h95, msgSubcode=8'h01
      if (tx.tx_valid && tx.tx_data[4:0] == 5'h12 && tx.tx_data[21:14] == 8'h95 && tx.tx_data[39:32] == 8'h01) begin
         if (!saw_sbinit_done_req) begin
            `uvm_info("SCOREBOARD", "SB-07 Partial: DUT sent {SBINIT done req}", UVM_LOW)
            saw_sbinit_done_req = 1;
         end
      end

      // SB-07 Check: Track if TB sent done resp
      // Check opcode=5'h12, msgCode=8'h9A, msgSubcode=8'h01
      if (tx.rx_valid && tx.rx_data[4:0] == 5'h12 && tx.rx_data[21:14] == 8'h9A && tx.rx_data[39:32] == 8'h01) begin
         if (!saw_sbinit_done_resp) begin
            `uvm_info("SCOREBOARD", "SB-07 Partial: TB sent {SBINIT done resp}", UVM_LOW)
            saw_sbinit_done_resp = 1;
         end
      end

      // Track FSM timeout error
      if (tx.fsm_error) begin
         `uvm_info("SCOREBOARD", "SB-04/FSM Error: Module raised timeout/error flag", UVM_LOW)
         fsm_error_raised = 1;
      end

      if (tx.fsm_done) begin
         if (saw_sbinit_done_req && saw_sbinit_done_resp && !sb_07_verified) begin
            `uvm_info("SCOREBOARD", "SB-07 Verified: DUT sent {SBINIT done req} and waited for {SBINIT done resp} before exiting", UVM_LOW)
            sb_07_verified = 1;
         end

         if (tb_sent_early_done_req && !dut_sent_early_done_resp && !sb_08_verified) begin
            `uvm_info("SCOREBOARD", "SB-08 Verified: DUT correctly ignored early {SBINIT done req}", UVM_LOW)
            sb_08_verified = 1;
         end

         `uvm_info("SCOREBOARD", "FSM Done: SBINIT sequence completed", UVM_LOW)
         saw_sbinit_done = 1;
      end
    end
  endtask

  function void check_phase(uvm_phase phase);
    // At the end, report what we collected
    `uvm_info("SCOREBOARD", $sformatf("Final stats: saw_clock_pattern=%0b, sb_02=%0b, sb_03=%0b, sb_05=%0b, sb_06=%0b, sb_07=%0b, sb_08=%0b, fsm_done=%0b, error=%0b", saw_clock_pattern, sb_02_verified, sb_03_verified, sb_05_verified, sb_06_verified, sb_07_verified, sb_08_verified, saw_sbinit_done, fsm_error_raised), UVM_LOW)
  endfunction

endclass
`endif
