`ifndef SBINIT_RSP_MONITOR_SV
`define SBINIT_RSP_MONITOR_SV

class sbinit_rsp_monitor extends uvm_monitor;
  `uvm_component_utils(sbinit_rsp_monitor)

  virtual logphy_if vif;
  uvm_analysis_port #(sbinit_rsp_transaction) rsp_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    rsp_ap = new("rsp_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual logphy_if)::get(this, "", "sbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_rsp_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    sbinit_rsp_transaction tx;
    logic [127:0] prev_tx_data;
    logic [127:0] prev_rx_data;
    logic         prev_tx_valid;
    logic         prev_rx_valid;
    logic         prev_tx_ready;

    prev_tx_data  = 128'h0;
    prev_rx_data  = 128'h0;
    prev_tx_valid = 0;
    prev_rx_valid = 0;
    prev_tx_ready = 0;

    forever begin
      @(posedge vif.clock);

      if ((vif.responderSbLaneIo_tx_valid !== prev_tx_valid) ||
          (vif.responderSbLaneIo_tx_valid && (vif.responderSbLaneIo_tx_bits_data !== prev_tx_data)) ||
          (vif.responderSbLaneIo_rx_valid !== prev_rx_valid) ||
          (vif.responderSbLaneIo_rx_valid && (vif.responderSbLaneIo_rx_bits_data !== prev_rx_data)) ||
          (vif.responderSbLaneIo_tx_ready !== prev_tx_ready) ||
          (vif.responderSbLaneIo_tx_valid && vif.responderSbLaneIo_tx_ready)) begin

        tx = sbinit_rsp_transaction::type_id::create("tx");
        tx.tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.tx_data  = vif.responderSbLaneIo_tx_bits_data;
        tx.tx_ready = vif.responderSbLaneIo_tx_ready;
        tx.rx_valid = vif.responderSbLaneIo_rx_valid;
        tx.rx_data  = vif.responderSbLaneIo_rx_bits_data;

        rsp_ap.write(tx);

        prev_tx_valid = vif.responderSbLaneIo_tx_valid;
        prev_tx_data  = vif.responderSbLaneIo_tx_bits_data;
        prev_rx_valid = vif.responderSbLaneIo_rx_valid;
        prev_rx_data  = vif.responderSbLaneIo_rx_bits_data;
        prev_tx_ready = vif.responderSbLaneIo_tx_ready;
      end
    end
  endtask

endclass

`endif
