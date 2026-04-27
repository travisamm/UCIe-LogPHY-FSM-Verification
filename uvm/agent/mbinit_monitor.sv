`ifndef MBINIT_MONITOR_SV
`define MBINIT_MONITOR_SV

class mbinit_monitor extends uvm_monitor;
  `uvm_component_utils(mbinit_monitor)

  virtual mbinit_if vif;
  uvm_analysis_port #(mbinit_transaction) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    mbinit_transaction tx;
    logic [2:0] prev_state;
    logic       prev_done;
    logic       prev_error;
    logic       prev_neg_valid;
    logic       prev_req_tx_valid;
    logic       prev_rsp_tx_valid;

    prev_state        = 3'hX;
    prev_done         = 0;
    prev_error        = 0;
    prev_neg_valid    = 0;
    prev_req_tx_valid = 0;
    prev_rsp_tx_valid = 0;

    forever begin
      @(posedge vif.clock);

      if ((vif.currentState !== prev_state)                      ||
          (vif.fsmCtrl_done !== prev_done)                       ||
          (vif.fsmCtrl_error !== prev_error)                     ||
          (vif.negotiatedPhySettings_valid !== prev_neg_valid)   ||
          (vif.requesterSbLaneIo_tx_valid !== prev_req_tx_valid) ||
          (vif.responderSbLaneIo_tx_valid !== prev_rsp_tx_valid)) begin

        tx = mbinit_transaction::type_id::create("tx");
        // Inherited observed fields (logphy_transaction)
        tx.fsm_done    = vif.fsmCtrl_done;
        tx.fsm_error   = vif.fsmCtrl_error;
        tx.tx_valid    = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data     = vif.requesterSbLaneIo_tx_bits_data;
        tx.rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.rsp_tx_data  = vif.responderSbLaneIo_tx_bits_data;
        // MBINIT-specific observed fields
        tx.currentState                = vif.currentState;
        tx.negotiatedPhySettings_valid = vif.negotiatedPhySettings_valid;
        tx.negotiated_maxDataRate      = vif.negotiatedPhySettings_maxDataRate;
        tx.negotiated_clockMode        = vif.negotiatedPhySettings_clockMode;
        tx.interoperableParamsNotFound = vif.interoperableParamsNotFound;
        tx.applyLaneReversal           = vif.applyLaneReversal;

        item_collected_port.write(tx);

        prev_state        = vif.currentState;
        prev_done         = vif.fsmCtrl_done;
        prev_error        = vif.fsmCtrl_error;
        prev_neg_valid    = vif.negotiatedPhySettings_valid;
        prev_req_tx_valid = vif.requesterSbLaneIo_tx_valid;
        prev_rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
      end
    end
  endtask

endclass
`endif
