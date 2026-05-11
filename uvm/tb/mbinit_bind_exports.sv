`ifndef MBINIT_BIND_EXPORTS_SV
`define MBINIT_BIND_EXPORTS_SV

// firtool/CIRCT keeps io_interoperableParamsNotFound internal; forward it to the TB VIF.
module mbinit_bind_exports (
    input wire io_interoperableParamsNotFound
);
  assign mbinit_tb_top.vif.interoperableParamsNotFound = io_interoperableParamsNotFound;
endmodule

bind MBInitSM mbinit_bind_exports u_mbinit_bind_exports (
    .io_interoperableParamsNotFound(io_interoperableParamsNotFound)
);

`endif
