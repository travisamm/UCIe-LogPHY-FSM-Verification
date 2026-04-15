`ifndef LOGPHY_MONITOR_SV
`define LOGPHY_MONITOR_SV

class logphy_monitor extends uvm_monitor;
  `uvm_component_utils(logphy_monitor)

  virtual logphy_if vif;
  uvm_analysis_port #(logphy_transaction) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual logphy_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    logphy_transaction tx;
    logic [127:0] prev_tx_data;
    
    // Initialize
    prev_tx_data = 128'h0;

    forever begin
      @(posedge vif.clock);
      
      // Sample every cycle or upon interesting events.
      // We will capture transactions when output data changes or FSM state changes to feed the scoreboard
      if (vif.requesterSbLaneIo_tx_valid && (vif.requesterSbLaneIo_tx_bits_data !== prev_tx_data)) begin
        tx = logphy_transaction::type_id::create("tx");
        tx.tx_valid = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data = vif.requesterSbLaneIo_tx_bits_data;
        tx.sbRxTxMode = vif.sbRxTxMode;
        tx.fsm_error = vif.fsmCtrl_error;
        tx.fsm_done = vif.fsmCtrl_done;
        
        item_collected_port.write(tx);
        prev_tx_data = vif.requesterSbLaneIo_tx_bits_data;
      end
      
      // Also capture state transitions (error / done)
      if (vif.fsmCtrl_error || vif.fsmCtrl_done) begin
        tx = logphy_transaction::type_id::create("tx");
        tx.tx_valid = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data = vif.requesterSbLaneIo_tx_bits_data;
        tx.sbRxTxMode = vif.sbRxTxMode;
        tx.fsm_error = vif.fsmCtrl_error;
        tx.fsm_done = vif.fsmCtrl_done;
        item_collected_port.write(tx);
      end
    end
  endtask

endclass
`endif
