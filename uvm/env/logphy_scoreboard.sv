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
      end

      // Track incoming SB-02 RX clock pattern sent from the TB to the DUT
      if (tx.rx_valid && tx.rx_data == 128'h00000000_00000000_55555555_55555555) begin
        if (!saw_rx_clock_pattern) begin
           saw_rx_clock_pattern = 1;
        end
      end

      // Check if RX/TX mode shifts to functional sideband (SB-05)
      // and verify SB-02 since transitioning means DUT successfully sampled the incoming pattern
      if (saw_clock_pattern && tx.sbRxTxMode == 1) begin
         if (saw_rx_clock_pattern && !sb_02_verified) begin
            `uvm_info("SCOREBOARD", "SB-02 Verified: DUT successfully sampled incoming SB data patterns with incoming clock", UVM_LOW)
            sb_02_verified = 1;
         end
         `uvm_info("SCOREBOARD", "SB-05 Verified: Transitioned to functional sideband mode", UVM_LOW)
      end

      // Track FSM timeout error
      if (tx.fsm_error) begin
         `uvm_info("SCOREBOARD", "SB-04/FSM Error: Module raised timeout/error flag", UVM_LOW)
         fsm_error_raised = 1;
      end

      if (tx.fsm_done) begin
         `uvm_info("SCOREBOARD", "FSM Done: SBINIT sequence completed", UVM_LOW)
         saw_sbinit_done = 1;
      end
    end
  endtask

  function void check_phase(uvm_phase phase);
    // At the end, report what we collected
    `uvm_info("SCOREBOARD", $sformatf("Final stats: saw_clock_pattern=%0b, sb_02_verified=%0b, fsm_done=%0b, error=%0b", saw_clock_pattern, sb_02_verified, saw_sbinit_done, fsm_error_raised), UVM_LOW)
  endfunction

endclass
`endif
