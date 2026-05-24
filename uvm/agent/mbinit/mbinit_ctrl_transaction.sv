`ifndef MBINIT_CTRL_TRANSACTION_SV
`define MBINIT_CTRL_TRANSACTION_SV

// ---------------------------------------------------------------------------
// mbinit_ctrl_transaction  (Pass 3)
// ---------------------------------------------------------------------------
// Drive item for the FSM-control bus: the one-shot FSM kick (start_fsm) plus the
// local PHY settings driven during PARAM negotiation. start_fsm is a level the
// RTL holds high until done; the ctrl driver latches it on the first item that
// asserts it and never clears it (matching the legacy driver's behavior).
// ---------------------------------------------------------------------------
class mbinit_ctrl_transaction extends uvm_sequence_item;
  rand logic        start_fsm;
  rand logic [4:0]  local_voltageSwing;
  rand logic [3:0]  local_maxDataRate;
  rand logic        local_clockMode;
  rand logic        local_clockPhase;
  rand logic        local_ucieSx8;
  rand logic        local_sbFeatExt;
  rand logic        local_txAdjRuntime;
  rand logic [1:0]  local_moduleId;
  rand int          delay;
  rand int          hold_cycles;

  `uvm_object_utils_begin(mbinit_ctrl_transaction)
    `uvm_field_int(start_fsm,          UVM_ALL_ON)
    `uvm_field_int(local_voltageSwing, UVM_ALL_ON)
    `uvm_field_int(local_maxDataRate,  UVM_ALL_ON)
    `uvm_field_int(local_clockMode,    UVM_ALL_ON)
    `uvm_field_int(local_clockPhase,   UVM_ALL_ON)
    `uvm_field_int(local_ucieSx8,      UVM_ALL_ON)
    `uvm_field_int(local_sbFeatExt,    UVM_ALL_ON)
    `uvm_field_int(local_txAdjRuntime, UVM_ALL_ON)
    `uvm_field_int(local_moduleId,     UVM_ALL_ON)
    `uvm_field_int(delay,              UVM_ALL_ON)
    `uvm_field_int(hold_cycles,        UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mbinit_ctrl_transaction");
    super.new(name);
    start_fsm          = 0;
    local_voltageSwing = 5'h1F;
    local_maxDataRate  = 4'hF;
    local_clockMode    = 1;
    local_clockPhase   = 0;
    local_ucieSx8      = 0;
    local_sbFeatExt    = 0;
    local_txAdjRuntime = 0;
    local_moduleId     = 0;
    delay              = 0;
    hold_cycles        = 1;
  endfunction
endclass

`endif
