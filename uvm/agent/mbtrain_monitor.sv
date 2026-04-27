`ifndef MBTRAIN_MONITOR_SV
`define MBTRAIN_MONITOR_SV

class mbtrain_monitor extends uvm_monitor;
  `uvm_component_utils(mbtrain_monitor)

  virtual mbtrain_if vif;
  uvm_analysis_port #(mbtrain_transaction) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbtrain_if)::get(this, "", "mbtrain_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    mbtrain_transaction tx;
    logic [3:0] prev_state;
    logic       prev_done;
    logic       prev_error;
    logic       prev_req_tx_valid;
    logic       prev_rsp_tx_valid;

    prev_state        = 4'hX;
    prev_done         = 0;
    prev_error        = 0;
    prev_req_tx_valid = 0;
    prev_rsp_tx_valid = 0;

    forever begin
      @(posedge vif.clock);

      if ((vif.currentState !== prev_state)                      ||
          (vif.fsmCtrl_done !== prev_done)                       ||
          (vif.fsmCtrl_error !== prev_error)                     ||
          (vif.requesterSbLaneIo_tx_valid !== prev_req_tx_valid) ||
          (vif.responderSbLaneIo_tx_valid !== prev_rsp_tx_valid)) begin

        tx = mbtrain_transaction::type_id::create("tx");
        // Inherited observed fields
        tx.fsm_done     = vif.fsmCtrl_done;
        tx.fsm_error    = vif.fsmCtrl_error;
        tx.tx_valid     = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data      = vif.requesterSbLaneIo_tx_bits_data;
        tx.rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.rsp_tx_data  = vif.responderSbLaneIo_tx_bits_data;
        // MBTrain-specific observed fields
        tx.currentState          = vif.currentState;
        tx.freqSel_valid         = vif.freqSel_valid;
        tx.freqSel_bits          = vif.freqSel_bits;
        tx.mbTrainTxSelfCalStart = vif.mbTrainTxSelfCalStart;
        tx.mbTrainRxClkCalStart  = vif.mbTrainRxClkCalStart;
        tx.doElectricalIdleTx    = vif.doElectricalIdleTx;
        tx.doElectricalIdleRx    = vif.doElectricalIdleRx;

        item_collected_port.write(tx);

        prev_state        = vif.currentState;
        prev_done         = vif.fsmCtrl_done;
        prev_error        = vif.fsmCtrl_error;
        prev_req_tx_valid = vif.requesterSbLaneIo_tx_valid;
        prev_rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
      end
    end
  endtask

endclass
`endif
