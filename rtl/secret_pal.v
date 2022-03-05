
// PAL16R6 (IC U001)

module secret_pal (
    input           clk,
    input  [9:2]    i,
    output [19:12]  o
);

// this clock is really the folling edge of TRAM WE (8000-8fff)
// the WE is latched on WAIT RESET2 ( vbl or low 3 bits of horz counter )
// the latch is preset by HC (bit 3) of horz counter
// output is anded with $7e before comparing to regster HL in the z80 code

// write tram -> read u001

// level start
//a5    1010 0101   ->  40  0100 0000
//cd    1100 1101   ->  16  0001 0110
//36    0011 0110   ->  7a  0111 1010
//6f    0110 1111   ->  3e  0011 1110

// extra scene
//a5    1010 0101   ->  40  0100 0000
//c2    1100 0010   ->  4c  0100 1100
//36    0011 0110   ->  2a  0010 1010
//6f    0110 1111   ->  66  0110 0110

reg method ;

assign o[19] = 0;
assign o[12] = 0;
assign o[18:13] = r[6:1];

reg [7:0] r;

always @ (posedge clk) begin
    if (          i[9:6] == 4'b1010 ) begin
        r <= 8'h40;
    end else if ( i[8:5] == 4'b1001 ) begin
        r <= 8'h16;
        method <= 0;
    end else if ( i[8:5] == 4'b1000 ) begin
        r <= 8'h4c;
        method <= 1;
    end else if ( i[9:6] == 4'b0011 && method == 0 ) begin
        r <= 8'h7a;
    end else if ( i[9:6] == 4'b0011 && method == 1 ) begin
        r <= 8'h2a;
    end else if ( i[9:6] == 4'b0110 && method == 0 ) begin
        r <= 8'h3e;
    end else if ( i[9:6] == 4'b0110 && method == 1 ) begin
        r <= 8'h66;
    end
        
    if ( i == 8'ha5 ) begin
        r <= 8'h40;
    end else if ( i == 8'hcd ) begin
        r <= 8'h16;
        method <= 0;
    end else if ( i == 8'hc2 ) begin
        r <= 8'h4c;
        method <= 1;
    end else if ( i == 8'h36 && method == 0 ) begin
        r <= 8'h7a;
    end else if ( i == 8'h36 && method == 1 ) begin
        r <= 8'h2a;
    end else if ( i == 8'h6f && method == 0 ) begin
        r <= 8'h3e;
    end else if ( i == 8'h6f && method == 1 ) begin
        r <= 8'h66;
    end
end

endmodule

