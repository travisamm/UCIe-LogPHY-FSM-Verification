`ifndef MBINIT_CAL_STUB_SV
`define MBINIT_CAL_STUB_SV

// ---------------------------------------------------------------------------
// mbinit_cal_stub  (Pass 3)
// ---------------------------------------------------------------------------
// CAL service responder on mb_cal_if: on each rising edge of cal_start, wait
// svc_cfg.cal_done_repeat_cycles, then pulse cal_done for one cycle. Replaces
// the legacy driver's cal auto-stub fork.
// ---------------------------------------------------------------------------
class mbinit_cal_stub extends uvm_component;
  `uvm_component_utils(mbinit_cal_stub)

  virtual mb_cal_if   vif;
  mbinit_service_cfg  svc_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_cal_if)::get(this, "", "mbinit_cal_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_cal_vif must be set for: ", get_full_name()})
    if (!uvm_config_db#(mbinit_service_cfg)::get(this, "", "mbinit_svc_cfg", svc_cfg))
      `uvm_fatal("NO_CFG", {"mbinit_svc_cfg must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    bit prev_start;
    prev_start = 1'b0;
    vif.drv_cb.cal_done <= 1'b0;
    forever begin
      @(vif.drv_cb);
      if (vif.drv_cb.cal_start && !prev_start) begin
        repeat (svc_cfg.cal_done_repeat_cycles) @(vif.drv_cb);
        vif.drv_cb.cal_done <= 1'b1;
        @(vif.drv_cb);
        vif.drv_cb.cal_done <= 1'b0;
      end
      prev_start = vif.drv_cb.cal_start;
    end
  endtask

endclass

`endif
