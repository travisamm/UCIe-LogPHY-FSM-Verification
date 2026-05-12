`ifndef MBTRAIN_COVERAGE_SV
`define MBTRAIN_COVERAGE_SV

class mbtrain_coverage extends uvm_component;
  `uvm_component_utils(mbtrain_coverage)
  uvm_analysis_imp #(mbtrain_transaction, mbtrain_coverage) analysis_export;

  covergroup mbtrain_cg with function sample(mbtrain_transaction t);
    option.per_instance = 1;
    option.name = "mbtrain_cg";
    option.cross_auto_bin_max = 0;

    cp_fsm_state: coverpoint t.currentState {
      bins VALVREF          = {4'h0};
      bins DATAVREF         = {4'h1};
      bins SPEEDIDLE        = {4'h2};
      bins TXSELFCAL        = {4'h3};
      bins RXCLKCAL         = {4'h4};
      bins VALTRAINCENTER   = {4'h5};
      bins VALTRAINVREF     = {4'h6};
      bins DATATRAINCENTER1 = {4'h7};
      bins DATATRAINVREF    = {4'h8};
      bins RAWDATASWEEP     = {4'h9};
      bins DATATRAINCENTER2 = {4'hA};
      bins LINKSPEED        = {4'hB};
    }
    cp_fsm_done: coverpoint t.fsm_done {
      bins done     = {1};
      bins not_done = {0};
    }
    cp_fsm_error: coverpoint t.fsm_error {
      bins error    = {1};
      bins no_error = {0};
    }
    cp_pll_lock: coverpoint t.pllLock {
      bins locked   = {1};
      bins unlocked = {0};
    }
    cp_goto_state: coverpoint t.goToState_valid {
      bins active   = {1};
      bins inactive = {0};
    }
    cp_txselfcal_start: coverpoint t.trainingTxSelfCalStart {
      bins asserted = {1};
      bins idle     = {0};
    }
    cp_txselfcal_done: coverpoint t.trainingTxSelfCalDone {
      bins done = {1};
      bins idle = {0};
    }
    cp_rxclkcal_start: coverpoint t.trainingRxClkCalStart {
      bins asserted = {1};
      bins idle     = {0};
    }
    cp_rxclkcal_done: coverpoint t.trainingRxClkCalDone {
      bins done = {1};
      bins idle = {0};
    }
    cp_training_req_start: coverpoint t.trainingReqStart {
      bins active = {1};
      bins idle   = {0};
    }
    cp_training_req_kind: coverpoint t.trainingReqTestKind {
      bins point_test = {2'h0};
      bins eye_sweep  = {2'h1};
      bins other      = {2'h2};
    }
    cp_training_resp_done: coverpoint t.trainingRespDone {
      bins done = {1};
      bins idle = {0};
    }
    cp_negotiated_rate: coverpoint t.negotiatedMaxDataRate {
      bins speed_4  = {4'h1};
      bins speed_8  = {4'h2};
      bins speed_16 = {4'h3};
      bins other    = default;
    }
    cp_pt_test_results: coverpoint t.ptTestResults_bits {
      bins all_pass = {16'hFFFF};
      bins all_fail = {16'h0000};
      bins partial  = default;
    }
    cp_tx_data_en: coverpoint t.mbLaneCtrl_txDataEn {
      bins all_enabled = {16'hFFFF};
      bins disabled    = {0};
      bins partial     = default;
    }
    cp_tx_clk_en: coverpoint t.mbLaneCtrl_txClkEn {
      bins enabled  = {1};
      bins disabled = {0};
    }
    cp_tx_valid_en: coverpoint t.mbLaneCtrl_txValidEn {
      bins enabled  = {1};
      bins disabled = {0};
    }
    cx_speedidle_paths: cross cp_pll_lock, cp_goto_state;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    mbtrain_cg = new();
  endfunction

  function void write(mbtrain_transaction t);
    mbtrain_cg.sample(t);
    `uvm_info("MBTRAIN_COV", "Coverage sampled!", UVM_HIGH)
  endfunction

endclass
`endif
