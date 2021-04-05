// binary counter 

module ttl161 
(
  input clk,
  input clear_n,
  input load_n,
  input [3:0] d,
  input t,
  input p,

  output ca,
  output [3:0] q
);

wire ca_current;
wire [3:0] q_next;
assign q_next = q_current + 1;

reg [3:0] q_current = 0;

always @(posedge clk or negedge clear_n) begin
    if (~clear_n) begin
        q_current <= 0;
    end else begin
        if (~load_n) begin
            q_current <= d;
        end
        if (load_n && t && p) begin
            q_current <= q_next;
        end
    end
end

// output
assign ca_current = t && (&q_current);

assign ca = ca_current;
assign q = q_current;

endmodule
