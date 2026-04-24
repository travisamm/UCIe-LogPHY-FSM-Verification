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
    logic [127:0] prev_rx_data;
    logic [127:0] prev_rsp_rx_data;
    logic [127:0] prev_rsp_tx_data;
    logic         prev_tx_valid;
    logic         prev_rx_valid;
    logic         prev_rsp_rx_valid;
    logic         prev_rsp_tx_valid;
    
    // Initialize
    prev_tx_data = 128'h0;
    prev_rx_data = 128'h0;
    prev_rsp_rx_data = 128'h0;
    prev_rsp_tx_data = 128'h0;
    prev_tx_valid = 0;
    prev_rx_valid = 0;
    prev_rsp_rx_valid = 0;
    prev_rsp_tx_valid = 0;

    forever begin
      @(posedge vif.clock);
      
      // Sample every cycle or upon interesting events.
      if ((vif.requesterSbLaneIo_tx_valid !== prev_tx_valid) || 
          (vif.requesterSbLaneIo_tx_valid && (vif.requesterSbLaneIo_tx_bits_data !== prev_tx_data)) ||
          (vif.requesterSbLaneIo_rx_valid !== prev_rx_valid) || 
          (vif.requesterSbLaneIo_rx_valid && (vif.requesterSbLaneIo_rx_bits_data !== prev_rx_data)) ||
          (vif.responderSbLaneIo_rx_valid !== prev_rsp_rx_valid) || 
          (vif.responderSbLaneIo_rx_valid && (vif.responderSbLaneIo_rx_bits_data !== prev_rsp_rx_data)) ||
          (vif.responderSbLaneIo_tx_valid !== prev_rsp_tx_valid) || 
          (vif.responderSbLaneIo_tx_valid && (vif.responderSbLaneIo_tx_bits_data !== prev_rsp_tx_data)) ||
          vif.fsmCtrl_error || vif.fsmCtrl_done) begin

        tx = logphy_transaction::type_id::create("tx");
        tx.tx_valid = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data = vif.requesterSbLaneIo_tx_bits_data;
        tx.rx_valid = vif.requesterSbLaneIo_rx_valid;
        tx.rx_data = vif.requesterSbLaneIo_rx_bits_data;
        tx.rsp_rx_valid = vif.responderSbLaneIo_rx_valid;
        tx.rsp_rx_data = vif.responderSbLaneIo_rx_bits_data;
        tx.rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.rsp_tx_data = vif.responderSbLaneIo_tx_bits_data;
        tx.sbRxTxMode = vif.sbRxTxMode;
        tx.fsm_error = vif.fsmCtrl_error;
        tx.fsm_done = vif.fsmCtrl_done;
        
        item_collected_port.write(tx);
        prev_tx_valid = vif.requesterSbLaneIo_tx_valid;
        prev_tx_data = vif.requesterSbLaneIo_tx_bits_data;
        prev_rx_valid = vif.requesterSbLaneIo_rx_valid;
        prev_rx_data = vif.requesterSbLaneIo_rx_bits_data;
        prev_rsp_rx_valid = vif.responderSbLaneIo_rx_valid;
        prev_rsp_rx_data = vif.responderSbLaneIo_rx_bits_data;
        prev_rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        prev_rsp_tx_data = vif.responderSbLaneIo_tx_bits_data;
      end
    end
  endtask

endclass
`endif
