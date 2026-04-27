module top;
  class trans;
    logic a;
    logic [7:0] b;
  endclass

  initial begin
    trans t = new();
    $display("a = %b, b = %b", t.a, t.b);
  end
endmodule
