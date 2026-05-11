class mbinit_coverage extends uvm_component;
  `uvm_component_utils(mbinit_coverage)

  uvm_analysis_imp #(mbinit_transaction, mbinit_coverage) analysis_export;

  covergroup mbinit_cg with function sample(mbinit_transaction t);

    // MP-01/02/03/06: PARAM negotiation
    cp_neg_valid: coverpoint t.negotiatedPhySettings_valid {
      bins valid   = {1};
      bins invalid = {0};
    }

    cp_neg_max_rate: coverpoint t.negotiated_maxDataRate {
      bins rate_set = {[1:$]};
      bins no_rate  = {0};
    }

    cp_neg_clk_mode: coverpoint t.negotiated_clockMode {
      bins mode_1 = {1};
      bins mode_0 = {0};
    }

    // MP-04: Interoperable params not found → error
    cp_interop_fail: coverpoint t.interoperableParamsNotFound {
      bins failed  = {1};
      bins success = {0};
    }

    // FSM state coverage (MC-01/02, RC-05, RV-07, LR-01/06, RM-08)
    cp_fsm_state: coverpoint t.currentState {
      bins PARAM      = {0};
      bins CAL        = {1};
      bins REPAIRCLK  = {2};
      bins REPAIRVAL  = {3};
      bins REVERSALMB = {4};
      bins REPAIRMB   = {5};
      bins TOMBTRAIN  = {6};
    }

    // RC-01: Lane enables
    cp_tx_clk_en: coverpoint t.mbLaneCtrl_txClkEn {
      bins enabled  = {1};
      bins disabled = {0};
    }

    cp_rx_clk_en: coverpoint t.mbLaneCtrl_rxClkEn {
      bins enabled  = {1};
      bins disabled = {0};
    }

    cp_tx_data_en: coverpoint t.mbLaneCtrl_txDataEn {
      bins all_enabled = {16'hFFFF};
      bins disabled    = {0};
      bins partial     = default;
    }

    // RC-02/RV-03/LR-02/RM-01: Pattern writer used
    cp_pattern_writer: coverpoint t.usingPatternWriter {
      bins active   = {1};
      bins inactive = {0};
    }

    cp_pattern_writer_type: coverpoint t.patternWriter_patternType {
      bins type_0 = {0};
      bins type_1 = {1};
      bins type_2 = {2};
      bins type_3 = {3};
    }

    // LR-03/RM-02: Pattern reader used
    cp_pattern_reader: coverpoint t.usingPatternReader {
      bins active   = {1};
      bins inactive = {0};
    }

    // RC-02: Point test start
    cp_pttest_start: coverpoint t.txPtTest_start {
      bins started = {1};
      bins idle    = {0};
    }

    // RV-02: Data lanes held low during valid repair
    cp_tx_valid_en: coverpoint t.mbLaneCtrl_txValidEn {
      bins enabled  = {1};
      bins disabled = {0};
    }

    // LR-04: Lane reversal detection
    cp_lane_reversal: coverpoint t.applyLaneReversal {
      bins reversed     = {1};
      bins not_reversed = {0};
    }

    // MP-04 cross: interop failure must cause fsm error
    cx_interop_error: cross cp_interop_fail, cp_fsm_state {
      bins interop_fail_in_param = binsof(cp_interop_fail.failed) &&
                                   binsof(cp_fsm_state.PARAM);
    }

    // FSM progression: PARAM → CAL → REPAIRCLK → REPAIRVAL → REVERSALMB → REPAIRMB → TOMBTRAIN
    cx_neg_valid_in_param: cross cp_neg_valid, cp_fsm_state {
      bins negotiated = binsof(cp_neg_valid.valid) &&
                        binsof(cp_fsm_state.PARAM);
    }

    // RC-01 cross: clk lanes enabled in REPAIRCLK
    cx_clk_en_in_repairclk: cross cp_tx_clk_en, cp_fsm_state {
      bins clk_enabled_repairclk = binsof(cp_tx_clk_en.enabled) &&
                                   binsof(cp_fsm_state.REPAIRCLK);
    }

    // RC-02 cross: pattern writer active in REPAIRCLK
    cx_pw_in_repairclk: cross cp_pattern_writer, cp_fsm_state {
      bins pw_active_repairclk = binsof(cp_pattern_writer.active) &&
                                 binsof(cp_fsm_state.REPAIRCLK);
    }

  endgroup : mbinit_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mbinit_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(mbinit_transaction t);
    mbinit_cg.sample(t);
    `uvm_info("COVERAGE", "MBINIT coverage sampled!", UVM_LOW)
  endfunction

endclass
