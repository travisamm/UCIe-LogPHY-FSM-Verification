`ifndef MBTRAIN_DRIVER_SV
`define MBTRAIN_DRIVER_SV

class mbtrain_driver extends uvm_driver #(mbtrain_transaction);
  `uvm_component_utils(mbtrain_driver)

  virtual mbtrain_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mbtrain_if)::get(this, "", "mbtrain_vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    // Idle defaults
    vif.fsmCtrl_start                = 0;
    vif.goToState_valid              = 0;
    vif.goToState_bits               = 0;
    vif.negotiatedMaxDataRate        = 3'h3;
    vif.pllLock                      = 1;
    vif.mbTrainTxSelfCalDone         = 0;
    vif.mbTrainRxClkCalDone          = 0;
    vif.phyInRetrain                 = 0;
    vif.interpretBy8Lane             = 0;
    vif.maxErrorThresholdPerLane     = 16'hFFFF;
    vif.changeInRuntimeLinkCtrlRegs  = 0;
    vif.currLocalTxFunctionalLanes   = 3'h7;
    vif.currRemoteTxFunctionalLanes  = 3'h7;
    vif.requesterSbLaneIo_rx_valid   = 0;
    vif.requesterSbLaneIo_rx_bits_data = 0;
    vif.requesterSbLaneIo_tx_ready   = 1;
    vif.responderSbLaneIo_rx_valid   = 0;
    vif.responderSbLaneIo_rx_bits_data = 0;
    vif.responderSbLaneIo_tx_ready   = 1;
    // Test intf req stubs — results
    vif.txPtTestReq_done                    = 0;
    vif.txPtTestReq_ptTestResults_valid     = 0;
    vif.txPtTestReq_ptTestResults_bits      = 16'hFFFF;
    vif.txEyeSweepReq_done                  = 0;
    vif.txEyeSweepReq_eyeSweepTestResults_valid = 0;
    vif.txEyeSweepReq_eyeSweepTestResults_bits  = 16'hFFFF;
    vif.rxPtTestReq_done                    = 0;
    vif.rxPtTestReq_ptTestResults_valid     = 0;
    vif.rxPtTestReq_ptTestResults_bits      = 16'hFFFF;
    vif.rxEyeSweepReq_done                  = 0;
    vif.rxEyeSweepReq_eyeSweepTestResults_valid = 0;
    vif.rxEyeSweepReq_eyeSweepTestResults_bits  = 16'hFFFF;
    // Test intf resp stubs
    vif.txPtTestResp_done    = 0;
    vif.txEyeSweepResp_done  = 0;
    vif.rxPtTestResp_done    = 0;
    vif.rxEyeSweepResp_done  = 0;

    wait(vif.reset == 0);

    fork
      // Main driver loop
      forever begin
        seq_item_port.get_next_item(req);
        drive_item(req);
        seq_item_port.item_done();
      end

      // Auto-stub: TxSelfCal — pulse done 3 cycles after start
      forever begin
        @(posedge vif.clock iff vif.mbTrainTxSelfCalStart);
        repeat(3) @(posedge vif.clock);
        vif.mbTrainTxSelfCalDone = 1;
        @(posedge vif.clock);
        vif.mbTrainTxSelfCalDone = 0;
      end

      // Auto-stub: RxClkCal — pulse done 3 cycles after start
      forever begin
        @(posedge vif.clock iff vif.mbTrainRxClkCalStart);
        repeat(3) @(posedge vif.clock);
        vif.mbTrainRxClkCalDone = 1;
        @(posedge vif.clock);
        vif.mbTrainRxClkCalDone = 0;
      end

      // Auto-stub: TxPtTest Requester
      forever begin
        @(posedge vif.clock iff vif.txPtTestReq_start);
        repeat(3) @(posedge vif.clock);
        vif.txPtTestReq_done               = 1;
        vif.txPtTestReq_ptTestResults_valid = 1;
        vif.txPtTestReq_ptTestResults_bits  = req.ptTestResults_bits;
        @(posedge vif.clock);
        vif.txPtTestReq_done               = 0;
        vif.txPtTestReq_ptTestResults_valid = 0;
      end

      // Auto-stub: TxEyeSweep Requester
      forever begin
        @(posedge vif.clock iff vif.txEyeSweepReq_start);
        repeat(3) @(posedge vif.clock);
        vif.txEyeSweepReq_done                     = 1;
        vif.txEyeSweepReq_eyeSweepTestResults_valid = 1;
        vif.txEyeSweepReq_eyeSweepTestResults_bits  = req.eyeSweepTestResults_bits;
        @(posedge vif.clock);
        vif.txEyeSweepReq_done                     = 0;
        vif.txEyeSweepReq_eyeSweepTestResults_valid = 0;
      end

      // Auto-stub: RxPtTest Requester
      forever begin
        @(posedge vif.clock iff vif.rxPtTestReq_start);
        repeat(3) @(posedge vif.clock);
        vif.rxPtTestReq_done               = 1;
        vif.rxPtTestReq_ptTestResults_valid = 1;
        vif.rxPtTestReq_ptTestResults_bits  = req.ptTestResults_bits;
        @(posedge vif.clock);
        vif.rxPtTestReq_done               = 0;
        vif.rxPtTestReq_ptTestResults_valid = 0;
      end

      // Auto-stub: RxEyeSweep Requester
      forever begin
        @(posedge vif.clock iff vif.rxEyeSweepReq_start);
        repeat(3) @(posedge vif.clock);
        vif.rxEyeSweepReq_done                     = 1;
        vif.rxEyeSweepReq_eyeSweepTestResults_valid = 1;
        vif.rxEyeSweepReq_eyeSweepTestResults_bits  = req.eyeSweepTestResults_bits;
        @(posedge vif.clock);
        vif.rxEyeSweepReq_done                     = 0;
        vif.rxEyeSweepReq_eyeSweepTestResults_valid = 0;
      end

      // Auto-stub: TxPtTest Responder
      forever begin
        @(posedge vif.clock iff vif.txPtTestResp_start);
        repeat(3) @(posedge vif.clock);
        vif.txPtTestResp_done = 1;
        @(posedge vif.clock);
        vif.txPtTestResp_done = 0;
      end

      // Auto-stub: TxEyeSweep Responder
      forever begin
        @(posedge vif.clock iff vif.txEyeSweepResp_start);
        repeat(3) @(posedge vif.clock);
        vif.txEyeSweepResp_done = 1;
        @(posedge vif.clock);
        vif.txEyeSweepResp_done = 0;
      end

      // Auto-stub: RxPtTest Responder
      forever begin
        @(posedge vif.clock iff vif.rxPtTestResp_start);
        repeat(3) @(posedge vif.clock);
        vif.rxPtTestResp_done = 1;
        @(posedge vif.clock);
        vif.rxPtTestResp_done = 0;
      end

      // Auto-stub: RxEyeSweep Responder
      forever begin
        @(posedge vif.clock iff vif.rxEyeSweepResp_start);
        repeat(3) @(posedge vif.clock);
        vif.rxEyeSweepResp_done = 1;
        @(posedge vif.clock);
        vif.rxEyeSweepResp_done = 0;
      end
    join
  endtask

  task drive_item(mbtrain_transaction req);
    if (req.delay > 0) begin
      vif.requesterSbLaneIo_rx_valid = 0;
      vif.responderSbLaneIo_rx_valid = 0;
      vif.fsmCtrl_start              = 0;
      repeat(req.delay) @(posedge vif.clock);
    end

    vif.fsmCtrl_start                   = req.start_fsm;
    vif.pllLock                         = req.pllLock;
    vif.goToState_valid                 = req.goToState_valid;
    vif.goToState_bits                  = req.goToState_bits;
    vif.negotiatedMaxDataRate           = req.negotiatedMaxDataRate;
    vif.phyInRetrain                    = req.phyInRetrain;
    vif.interpretBy8Lane                = req.interpretBy8Lane;
    vif.maxErrorThresholdPerLane        = req.maxErrorThresholdPerLane;
    vif.changeInRuntimeLinkCtrlRegs     = req.changeInRuntimeLinkCtrlRegs;
    vif.currLocalTxFunctionalLanes      = req.currLocalTxFunctionalLanes;
    vif.currRemoteTxFunctionalLanes     = req.currRemoteTxFunctionalLanes;
    vif.requesterSbLaneIo_rx_valid      = req.rx_valid;
    vif.requesterSbLaneIo_rx_bits_data  = req.rx_data;
    vif.responderSbLaneIo_rx_valid      = req.rsp_rx_valid;
    vif.responderSbLaneIo_rx_bits_data  = req.rsp_rx_data;

    repeat(req.hold_cycles > 0 ? req.hold_cycles : 1) @(posedge vif.clock);

    vif.fsmCtrl_start              = 0;
    vif.requesterSbLaneIo_rx_valid = 0;
    vif.responderSbLaneIo_rx_valid = 0;
  endtask

endclass
`endif
