`ifndef SBINIT_BASE_VSEQ_SV
`define SBINIT_BASE_VSEQ_SV

class sbinit_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(sbinit_base_vseq)

  sbinit_req_sequencer req_seqr;
  sbinit_rsp_sequencer rsp_seqr;

  function new(string name = "sbinit_base_vseq");
    super.new(name);
  endfunction

  task send_req_item(sbinit_req_transaction t);
    start_item(t, -1, req_seqr);
    finish_item(t, -1);
  endtask

  task send_rsp_item(sbinit_rsp_transaction t);
    start_item(t, -1, rsp_seqr);
    finish_item(t, -1);
  endtask

  virtual task body();
  endtask

endclass

`endif
