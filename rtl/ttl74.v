// flip-flop 

module ttl74 
(
    input clk,
    input clear_n,
    input preset_n,
    input d,
    
    output q,
    output q_n
);

reg q_current = 0;
reg preset_n_previous = 0;

always @(posedge clk or negedge clear_n) begin
    if (~clear_n) begin
        q_current <= 1'b0;
    end else if (~preset_n && preset_n_previous) begin
        q_current <= 1'b1;
    end else begin
        q_current <= d;
        preset_n_previous <= preset_n;
    end
end

assign q = q_current;
assign q_n = ~q_current;

endmodule
