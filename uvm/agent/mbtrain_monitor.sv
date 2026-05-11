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
    logic [3:0]  prev_state;
    logic        prev_done, prev_error;
    logic        prev_req_tx_valid, prev_rsp_tx_valid;
    logic [127:0] prev_req_tx_data, prev_rsp_tx_data;
    logic [15:0] prev_txDataEn, prev_rxDataEn;
    logic        prev_txClkEn, prev_txValidEn, prev_txTrackEn;
    logic        prev_rxClkEn, prev_rxValidEn, prev_rxTrackEn;
    logic        prev_rxPtStart, prev_rxEyeStart;
    logic [1:0]  prev_rxPtPattern, prev_rxEyePattern;
    logic [15:0] prev_rxPtBurst, prev_rxEyeBurst;
    logic        prev_rxPtRespStart, prev_rxEyeRespStart;
    logic [1:0]  prev_rxPtRespPattern, prev_rxEyeRespPattern;
    logic        prev_trainReady, prev_trainRespValid;
    logic [15:0] prev_trainRespBits;

    prev_state          = 4'hX;
    prev_done           = 0;
    prev_error          = 0;
    prev_req_tx_valid   = 0;
    prev_rsp_tx_valid   = 0;
    prev_req_tx_data    = 128'hX;
    prev_rsp_tx_data    = 128'hX;
    prev_txDataEn       = 16'hX;
    prev_txClkEn        = 1'bX;
    prev_txValidEn      = 1'bX;
    prev_txTrackEn      = 1'bX;
    prev_rxDataEn       = 16'hX;
    prev_rxClkEn        = 1'bX;
    prev_rxValidEn      = 1'bX;
    prev_rxTrackEn      = 1'bX;
    prev_rxPtStart      = 0;
    prev_rxEyeStart     = 0;
    prev_rxPtPattern    = 2'hX;
    prev_rxEyePattern   = 2'hX;
    prev_rxPtBurst      = 16'hX;
    prev_rxEyeBurst     = 16'hX;
    prev_rxPtRespStart  = 0;
    prev_rxEyeRespStart = 0;
    prev_rxPtRespPattern  = 2'hX;
    prev_rxEyeRespPattern = 2'hX;
    prev_trainReady     = 0;
    prev_trainRespValid = 0;
    prev_trainRespBits  = 16'hX;

    forever begin
      @(posedge vif.clock);

      if ((vif.currentState                    !== prev_state)          ||
          (vif.fsmCtrl_done                   !== prev_done)            ||
          (vif.fsmCtrl_error                  !== prev_error)           ||
          (vif.requesterSbLaneIo_tx_valid     !== prev_req_tx_valid)    ||
          (vif.responderSbLaneIo_tx_valid     !== prev_rsp_tx_valid)    ||
          (vif.requesterSbLaneIo_tx_bits_data !== prev_req_tx_data)      ||
          (vif.responderSbLaneIo_tx_bits_data !== prev_rsp_tx_data)      ||
          (vif.mbLaneCtrl_txDataEn            !== prev_txDataEn)        ||
          (vif.mbLaneCtrl_txClkEn             !== prev_txClkEn)         ||
          (vif.mbLaneCtrl_txValidEn           !== prev_txValidEn)       ||
          (vif.mbLaneCtrl_txTrackEn           !== prev_txTrackEn)       ||
          (vif.mbLaneCtrl_rxDataEn            !== prev_rxDataEn)        ||
          (vif.mbLaneCtrl_rxClkEn             !== prev_rxClkEn)         ||
          (vif.mbLaneCtrl_rxValidEn           !== prev_rxValidEn)       ||
          (vif.mbLaneCtrl_rxTrackEn           !== prev_rxTrackEn)       ||
          (vif.rxPtTestReq_start              !== prev_rxPtStart)       ||
          (vif.rxEyeSweepReq_start            !== prev_rxEyeStart)      ||
          (vif.rxPtTestReq_patternType        !== prev_rxPtPattern)     ||
          (vif.rxEyeSweepReq_patternType      !== prev_rxEyePattern)    ||
          (vif.rxPtTestReq_burstCount         !== prev_rxPtBurst)       ||
          (vif.rxEyeSweepReq_burstCount       !== prev_rxEyeBurst)      ||
          (vif.rxPtTestResp_start             !== prev_rxPtRespStart)   ||
          (vif.rxEyeSweepResp_start           !== prev_rxEyeRespStart)  ||
          (vif.rxPtTestResp_patternType       !== prev_rxPtRespPattern) ||
          (vif.rxEyeSweepResp_patternType     !== prev_rxEyeRespPattern)||
          (vif.trainingCtrl_req_readyForReq   !== prev_trainReady)      ||
          (vif.trainingCtrl_resp_results_valid!== prev_trainRespValid)  ||
          (vif.trainingCtrl_resp_results_bits !== prev_trainRespBits)) begin

        tx = mbtrain_transaction::type_id::create("tx");

        tx.fsm_done     = vif.fsmCtrl_done;
        tx.fsm_error    = vif.fsmCtrl_error;
        tx.tx_valid     = vif.requesterSbLaneIo_tx_valid;
        tx.tx_data      = vif.requesterSbLaneIo_tx_bits_data;
        tx.rsp_tx_valid = vif.responderSbLaneIo_tx_valid;
        tx.rsp_tx_data  = vif.responderSbLaneIo_tx_bits_data;

        tx.currentState          = vif.currentState;
        tx.freqSel_valid         = vif.freqSel_valid;
        tx.freqSel_bits          = vif.freqSel_bits;
        tx.trainingTxSelfCalStart = vif.trainingCtrl_txSelfCalStart;
        tx.trainingRxClkCalStart  = vif.trainingCtrl_rxClkCalStart;
        tx.doElectricalIdleTx    = vif.doElectricalIdleTx;
        tx.doElectricalIdleRx    = vif.doElectricalIdleRx;

        tx.trainingCapableIsTxType = vif.trainingCtrl_capableTest_isTxType;
        tx.trainingCapableIsRxType = vif.trainingCtrl_capableTest_isRxType;
        tx.trainingCapableTestKind = vif.trainingCtrl_capableTest_testKind;
        tx.trainingReqReadyForReq  = vif.trainingCtrl_req_readyForReq;
        tx.trainingRespInProgress  = vif.trainingCtrl_resp_inProgress;
        tx.trainingRespDone        = vif.trainingCtrl_resp_done;
        tx.trainingRespResultsValid = vif.trainingCtrl_resp_results_valid;
        tx.trainingRespResultsBits  = vif.trainingCtrl_resp_results_bits;
        tx.trainingRemoteRxSweepResultsValid = vif.trainingCtrl_remoteRxSweepResults_valid;
        tx.trainingRemoteRxSweepResultsBits  = vif.trainingCtrl_remoteRxSweepResults_bits;

        tx.rxPtTestReq_start             = vif.rxPtTestReq_start;
        tx.rxPtTestReq_clockPhase        = vif.rxPtTestReq_clockPhase;
        tx.rxPtTestReq_dataPattern       = vif.rxPtTestReq_dataPattern;
        tx.rxPtTestReq_validPattern      = vif.rxPtTestReq_validPattern;
        tx.rxPtTestReq_patternMode       = vif.rxPtTestReq_patternMode;
        tx.rxPtTestReq_iterationCount    = vif.rxPtTestReq_iterationCount;
        tx.rxPtTestReq_idleCount         = vif.rxPtTestReq_idleCount;
        tx.rxPtTestReq_burstCount        = vif.rxPtTestReq_burstCount;
        tx.rxPtTestReq_maxErrorThreshold = vif.rxPtTestReq_maxErrorThreshold;
        tx.rxPtTestReq_comparisonMode    = vif.rxPtTestReq_comparisonMode;
        tx.rxPtTestReq_patternType       = vif.rxPtTestReq_patternType;

        tx.rxEyeSweepReq_start             = vif.rxEyeSweepReq_start;
        tx.rxEyeSweepReq_clockPhase        = vif.rxEyeSweepReq_clockPhase;
        tx.rxEyeSweepReq_dataPattern       = vif.rxEyeSweepReq_dataPattern;
        tx.rxEyeSweepReq_validPattern      = vif.rxEyeSweepReq_validPattern;
        tx.rxEyeSweepReq_patternMode       = vif.rxEyeSweepReq_patternMode;
        tx.rxEyeSweepReq_iterationCount    = vif.rxEyeSweepReq_iterationCount;
        tx.rxEyeSweepReq_idleCount         = vif.rxEyeSweepReq_idleCount;
        tx.rxEyeSweepReq_burstCount        = vif.rxEyeSweepReq_burstCount;
        tx.rxEyeSweepReq_maxErrorThreshold = vif.rxEyeSweepReq_maxErrorThreshold;
        tx.rxEyeSweepReq_comparisonMode    = vif.rxEyeSweepReq_comparisonMode;
        tx.rxEyeSweepReq_patternType       = vif.rxEyeSweepReq_patternType;

        tx.rxPtTestResp_start        = vif.rxPtTestResp_start;
        tx.rxPtTestResp_patternType  = vif.rxPtTestResp_patternType;
        tx.rxEyeSweepResp_start      = vif.rxEyeSweepResp_start;
        tx.rxEyeSweepResp_patternType= vif.rxEyeSweepResp_patternType;

        tx.mbLaneCtrl_txDataEn  = vif.mbLaneCtrl_txDataEn;
        tx.mbLaneCtrl_txClkEn   = vif.mbLaneCtrl_txClkEn;
        tx.mbLaneCtrl_txValidEn = vif.mbLaneCtrl_txValidEn;
        tx.mbLaneCtrl_txTrackEn = vif.mbLaneCtrl_txTrackEn;
        tx.mbLaneCtrl_rxDataEn  = vif.mbLaneCtrl_rxDataEn;
        tx.mbLaneCtrl_rxClkEn   = vif.mbLaneCtrl_rxClkEn;
        tx.mbLaneCtrl_rxValidEn = vif.mbLaneCtrl_rxValidEn;
        tx.mbLaneCtrl_rxTrackEn = vif.mbLaneCtrl_rxTrackEn;

        item_collected_port.write(tx);

        prev_state          = vif.currentState;
        prev_done           = vif.fsmCtrl_done;
        prev_error          = vif.fsmCtrl_error;
        prev_req_tx_valid   = vif.requesterSbLaneIo_tx_valid;
        prev_rsp_tx_valid   = vif.responderSbLaneIo_tx_valid;
        prev_req_tx_data    = vif.requesterSbLaneIo_tx_bits_data;
        prev_rsp_tx_data    = vif.responderSbLaneIo_tx_bits_data;
        prev_txDataEn       = vif.mbLaneCtrl_txDataEn;
        prev_txClkEn        = vif.mbLaneCtrl_txClkEn;
        prev_txValidEn      = vif.mbLaneCtrl_txValidEn;
        prev_txTrackEn      = vif.mbLaneCtrl_txTrackEn;
        prev_rxDataEn       = vif.mbLaneCtrl_rxDataEn;
        prev_rxClkEn        = vif.mbLaneCtrl_rxClkEn;
        prev_rxValidEn      = vif.mbLaneCtrl_rxValidEn;
        prev_rxTrackEn      = vif.mbLaneCtrl_rxTrackEn;
        prev_rxPtStart      = vif.rxPtTestReq_start;
        prev_rxEyeStart     = vif.rxEyeSweepReq_start;
        prev_rxPtPattern    = vif.rxPtTestReq_patternType;
        prev_rxEyePattern   = vif.rxEyeSweepReq_patternType;
        prev_rxPtBurst      = vif.rxPtTestReq_burstCount;
        prev_rxEyeBurst     = vif.rxEyeSweepReq_burstCount;
        prev_rxPtRespStart  = vif.rxPtTestResp_start;
        prev_rxEyeRespStart = vif.rxEyeSweepResp_start;
        prev_rxPtRespPattern  = vif.rxPtTestResp_patternType;
        prev_rxEyeRespPattern = vif.rxEyeSweepResp_patternType;
        prev_trainReady     = vif.trainingCtrl_req_readyForReq;
        prev_trainRespValid = vif.trainingCtrl_resp_results_valid;
        prev_trainRespBits  = vif.trainingCtrl_resp_results_bits;
      end
    end
  endtask

endclass
`endif
