`ifndef MBINIT_PTTEST_RSP_STUB_SV
`define MBINIT_PTTEST_RSP_STUB_SV

// ---------------------------------------------------------------------------
// mbinit_pttest_rsp_stub  (Pass 3)
// ---------------------------------------------------------------------------
// Responder-side Tx point-test stub on mb_pttest_rsp_if: on each rising edge of
// start, pulse done three cycles later. Replaces the legacy driver's
// TxPtTestResp auto-stub fork.
// ---------------------------------------------------------------------------
class mbinit_pttest_rsp_stub extends uvm_component;
  `uvm_component_utils(mbinit_pttest_rsp_stub)

  virtual mb_pttest_rsp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_pttest_rsp_if)::get(this, "", "mbinit_pttest_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_pttest_rsp_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.done <= 1'b0;
    forever begin
      @(vif.drv_cb iff vif.drv_cb.start);
      repeat (3) @(vif.drv_cb);
      vif.drv_cb.done <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.done <= 1'b0;
    end
  endtask

endclass

`endif
