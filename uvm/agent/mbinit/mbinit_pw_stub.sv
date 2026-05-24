`ifndef MBINIT_PW_STUB_SV
`define MBINIT_PW_STUB_SV

// ---------------------------------------------------------------------------
// mbinit_pw_stub  (Pass 3)
// ---------------------------------------------------------------------------
// PatternWriter service responder on mb_pattern_writer_if: hold req_ready high,
// and on each req_valid pulse resp_complete five cycles later. Replaces the
// legacy driver's PatternWriter auto-stub fork.
// ---------------------------------------------------------------------------
class mbinit_pw_stub extends uvm_component;
  `uvm_component_utils(mbinit_pw_stub)

  virtual mb_pattern_writer_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_pattern_writer_if)::get(this, "", "mbinit_pw_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_pw_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.req_ready     <= 1'b1;
    vif.drv_cb.resp_complete <= 1'b0;
    forever begin
      @(vif.drv_cb iff vif.drv_cb.req_valid);
      repeat (5) @(vif.drv_cb);
      vif.drv_cb.resp_complete <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.resp_complete <= 1'b0;
    end
  endtask

endclass

`endif
