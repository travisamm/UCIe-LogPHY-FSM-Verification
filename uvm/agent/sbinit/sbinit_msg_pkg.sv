`ifndef SBINIT_MSG_PKG_SV
`define SBINIT_MSG_PKG_SV

package sbinit_msg_pkg;

  // ---- Opcodes ----
  localparam bit [4:0] SBINIT_OP_NO_DATA = 5'h12;
  localparam bit [4:0] SBINIT_OP_64DATA  = 5'h1B;

  // ---- Message codes / subcodes ----
  localparam bit [7:0] SBINIT_MC_OUT_OF_RESET = 8'h91;
  localparam bit [7:0] SBINIT_MC_DONE_REQ     = 8'h95;
  localparam bit [7:0] SBINIT_MC_DONE_RESP    = 8'h9A;
  localparam bit [7:0] SBINIT_SC_OOR          = 8'h00;
  localparam bit [7:0] SBINIT_SC_DONE         = 8'h01;

  // ---- 64-UI clock patterns the DUT/TB may emit on the SB lane ----
  localparam bit [127:0] SBINIT_CLK_PATTERN_A  = 128'hAAAAAAAAAAAAAAAA_00000000_00000000;
  localparam bit [127:0] SBINIT_CLK_PATTERN_5  = 128'h00000000_00000000_55555555_55555555;
  localparam bit [127:0] SBINIT_CLK_PATTERN_5A = 128'h55555555_55555555_00000000_00000000;
  localparam bit [127:0] SBINIT_CLK_PATTERN_A5 = 128'h00000000_00000000_AAAAAAAAAAAAAAAA;

  // Compare layout: spec-aligned field slices.
  function automatic bit is_sb_msg_compare_layout(logic [127:0] data,
                                                  bit [7:0] msg_code,
                                                  bit [7:0] msg_subcode);
    return data[4:0]   == SBINIT_OP_NO_DATA &&
           data[21:14] == msg_code          &&
           data[39:32] == msg_subcode;
  endfunction

  // Create layout: SBMsgCreate currently emits an 8-bit opcode (VecInit widens
  // the opcode), shifting message code / subcode up by 3 bits.
  function automatic bit is_sb_msg_create_layout(logic [127:0] data,
                                                 bit [7:0] msg_code,
                                                 bit [7:0] msg_subcode);
    return data[7:0]   == {3'b0, SBINIT_OP_NO_DATA} &&
           data[24:17] == msg_code                  &&
           data[42:35] == msg_subcode;
  endfunction

  // Either layout counts — Chisel can emit either depending on the path.
  function automatic bit is_sbinit_msg(logic [127:0] data,
                                       bit [7:0] mc,
                                       bit [7:0] sc);
    return is_sb_msg_compare_layout(data, mc, sc) ||
           is_sb_msg_create_layout (data, mc, sc);
  endfunction

  class sbinit_sb_msg;
    bit [4:0] opcode;
    bit [7:0] msg_code;
    bit [7:0] subcode;
    bit [63:0] payload;

    function new();
      opcode   = 5'h0;
      msg_code = 8'h0;
      subcode  = 8'h0;
      payload  = 64'h0;
    endfunction

    function logic [127:0] pack();
      logic [127:0] result;
      result          = 128'h0;
      result[4:0]     = opcode;
      result[21:14]   = msg_code;
      result[39:32]   = subcode;
      result[103:40]  = payload;
      return result;
    endfunction

    static function sbinit_sb_msg unpack(logic [127:0] data);
      sbinit_sb_msg m;
      m = new();
      m.opcode   = data[4:0];
      m.msg_code = data[21:14];
      m.subcode  = data[39:32];
      m.payload  = data[103:40];
      return m;
    endfunction
  endclass

endpackage

`endif
