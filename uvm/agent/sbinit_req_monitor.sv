`ifndef SBINIT_REQ_MONITOR_SV
`define SBINIT_REQ_MONITOR_SV

class sbinit_req_monitor extends uvm_monitor;
  `uvm_component_utils(sbinit_req_monitor)

  virtual sb_req_if  vif;       // requester sideband lane
  virtual sb_ctrl_if ctrl_vif;  // FSM control (observes done/error/mode/start)
  uvm_analysis_port #(sbinit_req_transaction) req_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_ap = new("req_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_req_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_req_vif must be set for: ", get_full_name()})
    if (!uvm_config_db#(virtual sb_ctrl_if)::get(this, "", "sbinit_ctrl_vif", ctrl_vif))
      `uvm_fatal("NO_VIF", {"sbinit_ctrl_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_req_transaction tx;
    logic [127:0] prev_tx_data;
    logic [127:0] prev_rx_data;
    logic         prev_tx_valid;
    logic         prev_rx_valid;
    logic         prev_tx_ready;
    logic         prev_sb_mode;
    logic         prev_fsm_done;
    logic         prev_fsm_error;

    prev_tx_data    = 128'h0;
    prev_rx_data    = 128'h0;
    prev_tx_valid   = 0;
    prev_rx_valid   = 0;
    prev_tx_ready   = 0;
    prev_sb_mode    = 0;
    prev_fsm_done   = 0;
    prev_fsm_error  = 0;

    forever begin
      @(posedge vif.clock);

      if ((vif.tx_valid !== prev_tx_valid) ||
          (vif.tx_valid && (vif.tx_bits_data !== prev_tx_data)) ||
          (vif.rx_valid !== prev_rx_valid) ||
          (vif.rx_valid && (vif.rx_bits_data !== prev_rx_data)) ||
          (vif.tx_ready !== prev_tx_ready) ||
          (ctrl_vif.sbRxTxMode    !== prev_sb_mode) ||
          (ctrl_vif.fsmCtrl_done  !== prev_fsm_done) ||
          (ctrl_vif.fsmCtrl_error !== prev_fsm_error) ||
          ctrl_vif.fsmCtrl_done   ||
          ctrl_vif.fsmCtrl_error) begin

        tx = sbinit_req_transaction::type_id::create("tx");
        tx.tx_valid      = vif.tx_valid;
        tx.tx_data       = vif.tx_bits_data;
        tx.tx_ready      = vif.tx_ready;
        tx.rx_valid      = vif.rx_valid;
        tx.rx_data       = vif.rx_bits_data;
        tx.sbRxTxMode    = ctrl_vif.sbRxTxMode;
        tx.fsm_done      = ctrl_vif.fsmCtrl_done;
        tx.fsm_error     = ctrl_vif.fsmCtrl_error;
        tx.fsmCtrl_start = ctrl_vif.fsmCtrl_start;

        req_ap.write(tx);

        prev_tx_valid  = vif.tx_valid;
        prev_tx_data   = vif.tx_bits_data;
        prev_rx_valid  = vif.rx_valid;
        prev_rx_data   = vif.rx_bits_data;
        prev_tx_ready  = vif.tx_ready;
        prev_sb_mode   = ctrl_vif.sbRxTxMode;
        prev_fsm_done  = ctrl_vif.fsmCtrl_done;
        prev_fsm_error = ctrl_vif.fsmCtrl_error;
      end
    end
  endtask

endclass

`endif
