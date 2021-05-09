
module video_timing (
    input clk,   // pixel clock
    input reset,     // reset

    input      [3:0] hs_offset,

    output     [7:0] v,  // { vd', vc', vb', va', vd, vc, vb, va }  
    output     [7:0] h,  // { hd', hc', hb', ha', hd, hc, hb, ha }  

    output     hbl,
    output     hbl_n,    
    output     hff,
    output     hx,
    output     hx_n,
    output reg vbl,
    output reg vbl_n,
    output reg vbls,
    output reg vbls_n,
    output reg hsync,     
    output reg vsync   
    );
    
// horizontal timings
//parameter HBLANK_START  = 256;
//parameter HSYNC_START   = 264;
//parameter HSYNC_END     = 304;
//parameter HBLANK_END    = 8;
//parameter H_TOTAL       = 312;

// vertical timings
//parameter VBLANK_START = 224;
//parameter VSYNC_START  = 256;
//parameter VSYNC_END    = 258;
//parameter VBLANK_END   = 32;
//parameter V_TOTAL      = 262;


// video syncs for mister.  not used ny mr. do
always @ (posedge clk) begin
    if ( hx == 1 && h == 8'd216 + $signed(hs_offset) ) begin
        hsync <= 1;
        if ( ~k3b_q ) begin
            if ( v == 8'd251 ) vsync <= 1;
            if ( v == 8'd254 ) vsync <= 0;
        end
    end else if ( hx == 1 && h == 8'd239 + $signed(hs_offset) ) begin
        hsync <= 0;
    end
end

reg k3a_q,k3b_q;

wire j3_ca,h3_ca,v4_ca,w4_ca;

wire g3_6 ;
assign g3_6 = ~( v[5] & v[6] & v[7] );
assign hff = w4_ca;


assign hx = k3a_q;
assign hx_n = ~k3a_q;


ttl161 v4 (
    .clk(clk),
    .clear_n(1),
    .load_n(~w4_ca),
    .t(1),
    .p(1),
    .d({hx_n,3'b000}),
    .q(h[3:0]),
    .ca(v4_ca)
    );

ttl161 w4 (
    .clk(clk),
    .clear_n(1),
    .load_n(~w4_ca),
    .t(v4_ca),
    .p(v4_ca),
    .d({hx_n,hx_n,2'b00}),
    .q(h[7:4]),
    .ca(w4_ca)
    );
    
always @ ( posedge clk ) begin
    if ( w4_ca == 1 ) begin
        k3a_q <= ~k3a_q;
    end
    
end
    
ttl74 w9_a (
  .clk(h[3]),
  .preset_n(~(hx & ~h[3])),
  .clear_n(1),
  .d(hx),
  .q(hbl),
  .q_n(hbl_n)
  );
    
ttl161 j3 (
    .clk(hx),
    .clear_n(1),
    .load_n(~h3_ca),
    .t(1),
    .p(1),
    .d({~k3b_q,1'b0,~k3b_q,1'b0} ),
    .q(v[3:0]),
    .ca(j3_ca)
    );

ttl161 h3 (
    .clk(hx),
    .clear_n(1),
    .load_n(~h3_ca),
    .t(j3_ca),
    .p(j3_ca),
    .d({~k3b_q,~k3b_q,~k3b_q,k3b_q}),
    .q(v[7:4]),
    .ca(h3_ca)
    );

reg prev_hx;    
reg prev_h3_ca;

always @ ( posedge clk ) begin
    prev_hx <= hx;

    if ( prev_hx == 1 && hx == 0 ) begin
        prev_h3_ca <= h3_ca;
    end
    
    // rising edge of hx_n
    if ( prev_h3_ca == 1 && prev_hx == 1 && hx == 0 ) begin
        k3b_q <= ~k3b_q;
    end
    
    if ( ~g3_6 ) begin // G3 Nand
        // preset
        vbl <= 1 ;
        vbl_n <= 0;
        vbls <= 1 ;
        vbls_n <= 0;
    end else begin
        // rising edge of hx and rising edge of v[5]
        if ( prev_hx == 0 && hx == 1 && v[5:4] == 2'b10 ) begin
            vbl <= k3b_q ;
            vbl_n <= ~k3b_q;
        end
        
        // rising edge of hx and rising edge of v[3]
        if ( prev_hx == 0 && hx == 1 && v[3:2] == 2'b10 ) begin
            vbls <= k3b_q ;
            vbls_n <= ~k3b_q;
        end
    end
end


endmodule
    