///----------------------------------------------------------------------------
//
//  Arcade: Mr Do! Copyright 2021 Darren Olafson
//
//  MiSTer Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//----------------------------------------------------------------------------

`default_nettype none

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_FREEZE = 0;
assign VGA_DISABLE = 0;

wire [1:0] aspect_ratio = status[2:1];
wire orientation = status[3];
wire [2:0] scan_lines = status[6:4];
wire [3:0] hs_offset = status[11:8];

assign VIDEO_ARX = (!aspect_ratio) ? (orientation  ? 8'd155 : 8'd96) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (orientation  ? 8'd96 : 8'd155) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A. Mr Do!;;",
	"O8B,CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"O12,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O3,Orientation,Vert,Horz;",
	"O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"H1OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
    "DIP;",
    "-;",
	"R0,Reset;",
	"J1,Jump,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};

// CLOCKS

wire pll_locked;

wire clk_98M;
wire clk_sys;
reg  clk_5M,clk_10M,clk_4M,clk_8M;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
    .outclk_0(clk_98M),     // 98
	.outclk_1(clk_sys),     // 49
	.locked(pll_locked)
);

reg [5:0] clk10_count;
reg [5:0] clk5_count;
reg [5:0] clk8_count;
reg [5:0] clk4_count;

always @ (posedge clk_98M) begin
    if ( RESET == 1 ) begin
        clk10_count <= 0;
        clk5_count <= 0;
        clk4_count <= 0;
        
    end else begin
        if ( clk10_count == 4 ) begin
            clk10_count <= 0;
            clk_10M <= ~ clk_10M ;
        end else begin
            clk10_count <= clk10_count + 1;
        end

        if ( clk8_count == 5 ) begin
            clk8_count <= 0;
            clk_8M <= ~ clk_8M ;
        end else begin
            clk8_count <= clk8_count + 1;
        end

        if ( clk5_count == 9 ) begin
            clk5_count <= 0;
            clk_5M <= ~ clk_5M ;
        end else begin
            clk5_count <= clk5_count + 1;
        end

        if ( clk4_count == 11 ) begin
            clk4_count <= 0;
            clk_4M <= ~ clk_4M ;
        end else begin
            clk4_count <= clk4_count + 1;
        end
    end
end

// INPUT

// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire  [7:0]	ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

wire b_up      = joy[3];
wire b_down    = joy[2];
wire b_left    = joy[1];
wire b_right   = joy[0];
wire b_fire    = joy[4];

wire b_up_2    = joy[3];
wire b_down_2  = joy[2];
wire b_left_2  = joy[1];
wire b_right_2 = joy[0];
wire b_fire_2  = joy[4];

wire b_start1  = joy[5];
wire b_start2  = joy[6];
wire b_coin    = joy[7];
wire b_pause   = joy[8];

// PAUSE SYSTEM
wire				pause_cpu;
wire [11:0]		rgb_out;
pause #(4,4,4,48) pause (
	.*,
	.r(rgb_comp[11:8]),
	.g(rgb_comp[7:4]),
	.b(rgb_comp[3:0]),
	.user_button(b_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

reg [7:0] p1 ;
reg [7:0] p2;
reg [7:0] dsw1 ;
reg [7:0] dsw2 ;
reg user_flip;

always @ (posedge clk_4M ) begin
    p1 <= ~{ 1'b0, b_start2, b_start1, b_fire, b_up, b_right, b_down, b_left };
    p2 <= ~{ b_coin, 1'b0, 1'b0, b_fire_2, b_up_2, b_right_2, b_down_2, b_left_2 };
    
    dsw1 <= sw[0];
    dsw2 <= sw[1];
    
    user_flip <= sw[2][0]; // not in original hardware.
end

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

wire no_rotate = orientation | direct_video;

wire [11:0] rgb_comp;

reg ce_pix;

wire hbl;
wire vbl;
wire hx;
wire hff;

wire hbl_hx;
assign hbl_hx = hbl | hx;

wire hsync;
wire vsync;

wire [7:0] h;
wire [7:0] v;

wire rotate_ccw = 1;
wire flip = 0;
wire video_rotated;
screen_rotate screen_rotate (.*);

arcade_video #(240,12) arcade_video
(
        .*,

        .clk_video(clk_sys),
        .ce_pix(clk_5M),

        .RGB_in(rgb_out),
        .HBlank(hbl_hx),
        .VBlank(vbl),
        .HSync(hsync),
        .VSync(vsync),

        .fx(scan_lines)
);

wire reset;
assign reset = RESET | status[0] | ioctl_download | buttons[1];
wire rom_download = ioctl_download && !ioctl_index;



video_timing video_timing (
    .clk(~clk_5M),   // pixel clock
    .reset(reset),     // reset

    .hs_offset(hs_offset),

    .h(h),  // { hd', hc', hb', ha', hd, hc, hb, ha }  
    .v(v),  // { vd', vc', vb', va', vd, vc, vb, va }  

    .hbl(hbl),
//    output      hbl_n,    
    .hff(hff),
    .hx(hx),
//    output      hx_n,
    .vbl(vbl),
//    output reg  vbl_n,
//    output reg  vbls,
//    output reg  vbls_n,
    
    .hsync(hsync),     
    .vsync(vsync)   
    );

  
wire [7:0] s8_data;
wire [7:0] u8_data;

wire [7:0] r8_data;
wire [7:0] n8_data;

wire [7:0] f10_data;
reg [5:0] f10_addr;    

reg [9:0]  fg_char_index ; 
reg [9:0]  bg_char_index ; 

reg [15:0] cpu_addr;
reg  [7:0] cpu_din;
wire [7:0] cpu_dout;

wire [7:0] gfx_fg_tile_data ; 
wire [7:0] gfx_fg_attr_data ; 

wire [7:0] gfx_bg_tile_data ; 
wire [7:0] gfx_bg_attr_data ; 

reg [7:0]  wr_data;
reg [11:0] wr_addr;

reg cpu_ram_w ;

reg gfx_fg_ram0_wr ;
reg gfx_fg_ram1_wr ;
reg gfx_bg_ram0_wr ;
reg gfx_bg_ram1_wr ;

wire [7:0] fg_ram0_data;
wire [7:0] fg_ram1_data;
wire [7:0] bg_ram0_data;
wire [7:0] bg_ram1_data;

wire [7:0] cpu01rom_data;
wire [7:0] cpu02rom_data;
wire [7:0] cpu03rom_data;
wire [7:0] cpu04rom_data;
wire [7:0] cpu_ram_data;

// used to shift out the bitmap
reg [7:0] fg_shift_0;
reg [7:0] fg_shift_1;
reg [7:0] bg_shift_0;
reg [7:0] bg_shift_1;

reg [7:0] fg_attr;
reg [7:0] bg_attr;

reg [11:0] fg_bitmap_addr;
reg [11:0] bg_bitmap_addr;

// fg ----------
//
wire [1:0] fg = { fg_shift_1[0], fg_shift_0[0] };
//
reg [1:0] fg_reg;

reg [7:0] fg_attr_reg;

reg [7:0] fg_red ;
reg [7:0] fg_green ;
reg [7:0] fg_blue ;

// values the same for each channel. put this into a module
always @ ( posedge clk_10M ) begin
    case ({ fg_pal_data_high[1:0] , fg_pal_data_low[1:0] })
        0  : fg_red <= 0;
        1  : fg_red <= 0;
        2  : fg_red <= 0;
        3  : fg_red <= 88;
        4  : fg_red <= 0;
        5  : fg_red <= 112;
        6  : fg_red <= 133;
        7  : fg_red <= 192;
        8  : fg_red <= 60;
        9  : fg_red <= 150;
        10 : fg_red <= 166;
        11 : fg_red <= 212;
        12 : fg_red <= 180;
        13 : fg_red <= 221;
        14 : fg_red <= 229;
        15 : fg_red <= 255;
    endcase
    case ({ fg_pal_data_high[3:2] , fg_pal_data_low[3:2] })
        0  : fg_green <= 0;
        1  : fg_green <= 0;
        2  : fg_green <= 0;
        3  : fg_green <= 88;
        4  : fg_green <= 0;
        5  : fg_green <= 112;
        6  : fg_green <= 133;
        7  : fg_green <= 192;
        8  : fg_green <= 60;
        9  : fg_green <= 150;
        10 : fg_green <= 166;
        11 : fg_green <= 212;
        12 : fg_green <= 180;
        13 : fg_green <= 221;
        14 : fg_green <= 229;
        15 : fg_green <= 255;
    endcase
    case ({ fg_pal_data_high[5:4] , fg_pal_data_low[5:4] })
        0  : fg_blue <= 0;
        1  : fg_blue <= 0;
        2  : fg_blue <= 0;
        3  : fg_blue <= 88;
        4  : fg_blue <= 0;
        5  : fg_blue <= 112;
        6  : fg_blue <= 133;
        7  : fg_blue <= 192;
        8  : fg_blue <= 60;
        9  : fg_blue <= 150;
        10 : fg_blue <= 166;
        11 : fg_blue <= 212;
        12 : fg_blue <= 180;
        13 : fg_blue <= 221;
        14 : fg_blue <= 229;
        15 : fg_blue <= 255;
    endcase
end

//
//// bg ----------
//
wire [1:0] bg = { bg_shift_1[0], bg_shift_0[0] };
//
reg [1:0] bg_reg;
reg [7:0] bg_attr_reg;

reg [4:0] fg_pal_ofs_hi ;
reg [4:0] fg_pal_ofs_low ;

reg [4:0] sp_pal_ofs_hi ;
reg [4:0] sp_pal_ofs_low ;

reg [7:0] bg_scroll_y;
reg [7:0] bg_scroll_x;

wire [7:0] bg_scroll;
assign bg_scroll = user_flip ? (v + ~bg_scroll_y) : v + bg_scroll_y;

//// ---------- sprites ----------
reg spr_ram_wr;   
reg [7:0] spr_addr;
wire [7:0] spr_ram_data;

reg [7:0] spr_shift_data;

reg [7:0] sprite_tile;
reg [7:0] sprite_x;
reg [7:0] sprite_y;
reg [7:0] sprite_color;
//reg [7:0] sprite_x;
reg sprite_valid;

wire [7:0] h5_data;
wire [7:0] k5_data;
reg [11:0] spr_bitmap_addr;

//reg [7:0] spr_data_latch;

    // [0] tile #
    // [1] y
    // [2] color
    // [3] x
    
// --------------- fg / bg ------------

reg [5:0] sp_addr_cache[15:0];  
reg [5:0] a7;
reg [3:0] a9;

reg [3:0] f8_buf[256];
reg [7:0] f8_count;

reg [3:0] g8_buf[256];
reg [7:0] g8_count;

reg [1:0] pad ;
reg [1:0] pic ;
reg [7:0] h10 ; // counter h10 LS393 drives timing prom J10
reg [3:0] k6;
reg [3:0] j6;
reg load_shift;
reg dec_a9;

wire sp_bank = ( sprite_tile[6] == 1 );
wire flip_x  = ( sprite_color[4] == 1 );
wire flip_y  = ( sprite_color[5] == 1 );
reg cocktail_flip;

// hbl is made 64 clocks
always @ (posedge clk_10M) begin
    if ( hbl_hx ) begin
        // clocked on the rising edge of HA. ie h[0]
        if ( clk_5M == 1 && h[0] == 1 ) begin
            // if tile is visible and still room in address stack
            if ( j7[7:4] == 0 && a9 < 15 ) begin
                sp_addr_cache[a9][5:0] <= a7;
                a9 <= a9 + 1;
            end 
            a7 <= a7 + 1;
        end
        h10 <= 0;
    end else begin
        // reset a9 on last pixel of playfield
        // should be zero anyways if a9 counted down correctly
        if ( hff == 1 ) begin
            a9 <= 0;
        end else if ( dec_a9 == 1 ) begin
            // a9 counts down on falling edge of pic1 when a9 > 0 and ~hbl 
            if ( a9 > 0 ) begin
                 a9 <= a9 - 1;
            end
        end

        h10 <= h10 + 1;
        a7 <= 0;
    end
end

always @ ( posedge clk_10M ) begin // neg
    // load new nibbles into the shifters
    // if not loading then shifting out
    if ( load_shift == 1 ) begin
        // select rom bank
        if ( sp_bank == 0 ) begin
            // cheat and swizzle the nibble before shifting
            if ( flip_x == 0 ) begin
                k6 <= h5_data[3:0];
                j6 <= h5_data[7:4];
                f10_addr <= {sprite_color[2:0], h5_data[0], h5_data[4]};
            end else begin
                k6 <= { h5_data[0], h5_data[1], h5_data[2], h5_data[3] };
                j6 <= { h5_data[4], h5_data[5], h5_data[6], h5_data[7] };
                f10_addr <= {sprite_color[2:0], h5_data[3], h5_data[7]};
            end
        end else begin
            if ( flip_x == 0 ) begin
                k6 <= k5_data[3:0];
                j6 <= k5_data[7:4];
                f10_addr <= {sprite_color[2:0], k5_data[0], k5_data[4]};
            end else begin
                k6 <= { k5_data[0], k5_data[1], k5_data[2], k5_data[3] };
                j6 <= { k5_data[4], k5_data[5], k5_data[6], k5_data[7] };
                f10_addr <= {sprite_color[2:0], k5_data[3], k5_data[7]};
            end
        end
    end else begin
        // the flip_x bit doesn't matter since the bits were re-ordered at load.
        k6 <= { 1'b0, k6[3:1]  };
        j6 <= { 1'b0, j6[3:1]  };
        // get one clock early.  not sure this works.
        f10_addr <= {sprite_color[2:0], k6[1], j6[1]};
    end


    
    // counters are always cleared during hbl
    // one will free count and the other will count the x offset in the current blitter
    // v[0] (schematic VADLAY) determines which buffer is blitting and which is streaming
    if ( hbl ) begin
        f8_count <= 0;
        g8_count <= 0;
    end else if ( pad[1:0] == 2'b11 ) begin
        // mux G9 gives LA4 ( L9 nand pad 1+0 ) to F8 or G8 load line
        // load one from sprite x pos, increment the other
        if ( v[0] == 1 ) begin
            f8_count <= spr_ram_data ;
            if ( clk_5M == 1 ) begin
                g8_count <= g8_count + 1;
            end
        end else begin
            g8_count <= spr_ram_data ;
            if ( clk_5M == 1 ) begin
                f8_count <= f8_count + 1;
            end
        end
    end else begin 
        // increment both
        if ( v[0] == 1 ) begin
            if ( sprite_valid ) begin
                f8_count <= f8_count + 1;
            end
            if ( clk_5M == 1 ) begin
                g8_count <= g8_count + 1;
            end
        end else begin
            if ( sprite_valid ) begin
                g8_count <= g8_count + 1;
            end
            if ( clk_5M == 1 ) begin
                f8_count <= f8_count + 1;
            end
        end
    end
end


always @ ( posedge clk_10M ) begin
    // odd / even lines each have their own sprite line buffer
    if ( v[0] == 1 ) begin
        // if the pixel color is 0 then the ram cs is not asserted and no write happens
        if ( k6[0] | j6[0] ) begin
            if ( sprite_valid ) begin
                // sprite_color[3] selects high or low nibble of sprite color lookup
                if ( sprite_color[3] == 0 ) begin
                    f8_buf[f8_count][3:0] <= f10_data[3:0];
                end else begin
                    f8_buf[f8_count][3:0] <= f10_data[7:4];
                end
            end
        end
        
        // buffer on pcb is cleared by pull-downs on the output bus
        // the ram we is asserted after the output is latched then the zero value is written on the opposite 10MHz edge.
        // address clock on the streaming buffer is at 5M.  It writes when the clock is high because clock gets inverted by L9
        
        if ( clk_5M == 1 && ~hbl_hx ) begin
            g8_buf[g8_count_flip][3:0] <= 0;
        end
    end else begin
        if ( k6[0] | j6[0] ) begin
            if ( sprite_valid ) begin
                // sprite_color[3] selects high or low nibble of sprite color lookup
                if ( sprite_color[3] == 0 ) begin
                    g8_buf[g8_count][3:0] <= f10_data[3:0];
                end else begin
                    g8_buf[g8_count][3:0] <= f10_data[7:4];
                end
            end
        end
        if ( clk_5M == 1 && ~hbl_hx ) begin
            f8_buf[f8_count_flip][3:0] <= 0;
        end
        
    end
end

reg [4:0] spr_pal_ofs_hi;
reg [4:0] spr_pal_ofs_low;

wire [7:0] g8_count_flip;
assign g8_count_flip = user_flip ? ~g8_count : g8_count;

wire [7:0] f8_count_flip;
assign f8_count_flip = user_flip ? ~f8_count : f8_count;

// sprite buffer handling
always @ (posedge clk_10M) begin   
    if ( clk_5M == 0 ) begin
        // default to clear
        spr_pal_ofs_hi <= 0;
        spr_pal_ofs_low <= 0;
        
        if ( v[0] == 1 && g8_buf[g8_count_flip] > 0 ) begin
            spr_pal_ofs_hi  <= { 1'b0, g8_buf[g8_count_flip] };
            spr_pal_ofs_low <= { 1'b0, g8_buf[g8_count_flip][3:2], g8_buf[g8_count_flip][1:0] };
        end 
        if ( v[0] == 0 && f8_buf[f8_count_flip] > 0 ) begin
            spr_pal_ofs_hi  <= { 1'b0, f8_buf[f8_count_flip] };
            spr_pal_ofs_low <= { 1'b0, f8_buf[f8_count_flip][3:2], f8_buf[f8_count_flip][1:0] };
        end
    end 
end

always @ (posedge clk_10M) begin     // neg   
    // data in spr_ram_data
    // { pad[7:2], pad[1:0] } on the schematic.  pad counter
    // is h counter really reset and the same time as pad counter (A7)?
    if ( hbl_hx ) begin
        // 64 cycles of checking if y active and storing a7 if it is
        spr_addr <= { a7[5:0], 2'b01 };  // only y
    end else begin
        spr_addr <= { sp_addr_cache[a9], pad[1:0] };  // only y 63-0
    end
    
    if ( ~hbl_hx ) begin
    
        // set the current position into the bitmap rom based on the tile, 
        // y offset and bitmap byte offset
         // last 2 bits are from timing prom pad[0] & pad[1] 
         // if ( sprite_color[5] == 0 ) begin
         if ( flip_y == 0 ) begin
            if ( flip_x == 0 ) begin
                spr_bitmap_addr <= { sprite_tile[5:0], sprite_y[3:0], pic[1:0] } ; 
            end else begin
                spr_bitmap_addr <= { sprite_tile[5:0], sprite_y[3:0], ~pic[1:0] } ; 
            end
         end else begin
            if (  flip_x == 0 ) begin
                spr_bitmap_addr <= { sprite_tile[5:0], ~sprite_y[3:0], pic[1:0] } ; 
            end else begin
                spr_bitmap_addr <= { sprite_tile[5:0], ~sprite_y[3:0], ~pic[1:0] } ; 
            end
         end
         
     end
end

// sprites are added to a visible list during the hblank of the previous line
wire [7:0]j7 = user_flip ? (spr_ram_data + ~(v+1)) : spr_ram_data + (v+1);

always @ (posedge clk_10M) begin

    // J10 logic
    // 8 clocks per sprite
    // even is falling 5M clk
    // timing altered from prom to deal with async/sync differences 
    case ( h10[4:0] )
        0:  begin
                pad <= 2'b00;
                pic <= 2'b00;
                load_shift <= 0;
            end
        2:  begin
                sprite_tile <= spr_ram_data;
                //sprite_tile <= 8'h06;
                pad <= 2'b01;
            end
        4:  begin
                sprite_y <= j7; // spr_ram_data + v ; 

                if ( spr_ram_data !== 0 && j7 < 16 ) begin
                    sprite_valid <= 1;
                end else begin
                    sprite_valid <= 0;
                end
                pad <= 2'b10;
            end
        6:  begin
                sprite_color <= spr_ram_data ;
                pad <= 2'b11;
            end
        8:  begin
                sprite_x <= spr_ram_data ;
//                    pad <= 2'b00; // different than prom value
            end
        9:  begin
                load_shift <= 1; 
            end
        10: begin
                        load_shift <= 0;
                // this should be at 8
                pad <= 2'b00;            
            end
        11: begin
                pic <= 2'b01;
            end
        13: begin
                load_shift <= 1; 
            end
        14: begin
                load_shift <= 0; 
            end
        15: begin
                pic <= 2'b10;
            end
        17: begin
                load_shift <= 1; 
            end
        18: begin
                load_shift <= 0; 
            end
        19: begin
                pic <= 2'b11;
            end
        21: begin
                load_shift <= 1;
            end
        22: begin
                  load_shift <= 0;
            end
        26: begin
                dec_a9 <= 1;
            end
        27: begin
                dec_a9 <= 0;
                pic <= 2'b00;
            end
    endcase

end   

reg draw;


always @ (posedge clk_10M) begin   
    if ( clk_5M == 1 ) begin
        // load palette - calculate rom offsets
        // check if bg or fg asserted priority

        if ( spr_pal_ofs_hi > 0 && ( h > 16 || ~user_flip ) ) begin
            // the h > 16 condition is a screen flip hack.  not in original hardware
            fg_pal_ofs_hi  <= spr_pal_ofs_hi;
            fg_pal_ofs_low <= spr_pal_ofs_low;
            draw <= 1;
        end else if ( fg !== 0 || fg_attr[6] == 1 ) begin
            // fg
            fg_pal_ofs_hi  <= { fg_attr[2:0] , fg_shift_1[0], fg_shift_0[0] };
            fg_pal_ofs_low <= { fg_attr[5:3] , fg_shift_1[0], fg_shift_0[0] };
            draw <= 1;
            
        end else if ( bg != 0 || bg_attr[6] == 1 ) begin
            // bg
            fg_pal_ofs_hi  <= { bg_attr[2:0] , bg_shift_1[0], bg_shift_0[0] };
            fg_pal_ofs_low <= { bg_attr[5:3] , bg_shift_1[0], bg_shift_0[0] };
            draw <= 1;
        end else begin
            draw <= 0;
        end

        if ( h[2:0] !== 7 ) begin
            // unless we are loading the shift register then shift it.
            fg_shift_0 <= { fg_shift_0[0], fg_shift_0[7:1] };
            fg_shift_1 <= { fg_shift_1[0], fg_shift_1[7:1] };

            bg_shift_0 <= { bg_shift_0[0], bg_shift_0[7:1] };
            bg_shift_1 <= { bg_shift_1[0], bg_shift_1[7:1] };
            
        end
    
        // load / shift tiles
        case ( { cocktail_flip ^ user_flip, h[2:0] } )
            5:  begin
                    fg_char_index <= { v[7:3] , h[7:3] }  ; // 32*32 characters
                    bg_char_index <= { bg_scroll[7:3] , h[7:3] }  ; // 32*32 characters
                end
            6:  begin
                    fg_bitmap_addr <= { gfx_fg_attr_data[7], gfx_fg_tile_data, v[2:0] };
                    bg_bitmap_addr <= { gfx_bg_attr_data[7], gfx_bg_tile_data, bg_scroll[2:0] };
                end
            7:  begin 
                    // latched by N9/P9 & U9 & S9 on h[2:0] == 111 R6 creates latch clock
                    fg_shift_0 <= u8_data;
                    fg_shift_1 <= s8_data;
            
                    bg_shift_0 <= n8_data ;
                    bg_shift_1 <= r8_data ;
                    
                    fg_attr <= gfx_fg_attr_data;
                    bg_attr <= gfx_bg_attr_data; 
                end
            13:  begin
                    fg_char_index <= ~{ v[7:3] , h[7:3] }  ; // 32*32 characters
                    bg_char_index <= ~{ bg_scroll[7:3] , h[7:3] }  ; // 32*32 characters
                end
            14:  begin
                    fg_bitmap_addr <= { gfx_fg_attr_data[7], gfx_fg_tile_data, ~v[2:0] };
                    bg_bitmap_addr <= { gfx_bg_attr_data[7], gfx_bg_tile_data, ~bg_scroll[2:0] };
                end
            15: begin
                    fg_shift_0 <= { u8_data[0], u8_data[1], u8_data[2], u8_data[3], u8_data[4], u8_data[5], u8_data[6], u8_data[7]} ;
                    fg_shift_1 <= { s8_data[0], s8_data[1], s8_data[2], s8_data[3], s8_data[4], s8_data[5], s8_data[6], s8_data[7]} ;
            
                    bg_shift_0 <= { n8_data[0], n8_data[1], n8_data[2], n8_data[3], n8_data[4], n8_data[5], n8_data[6], n8_data[7]} ;
                    bg_shift_1 <= { r8_data[0], r8_data[1], r8_data[2], r8_data[3], r8_data[4], r8_data[5], r8_data[6], r8_data[7]} ;

                    fg_attr <= gfx_fg_attr_data;
                    bg_attr <= gfx_bg_attr_data; 
                end
             
        endcase
    end
end


wire [7:0] fg_pal_data_high;  // read from palette prom
wire [7:0] fg_pal_data_low;

wire [7:0] bg_pal_data_high;
wire [7:0] bg_pal_data_low;

always @ (posedge clk_5M ) begin
    if ( ~hbl_hx & ~vbl ) begin // LS32 R2
        if ( draw ) begin
            rgb_comp <= { fg_red[7:4], fg_green[7:4], fg_blue[7:4] };
        end else begin
            rgb_comp <=  0;
        end
    end else begin
        // vblank / hblank
        rgb_comp <= 0;
    end
end    

reg [15:0] unhandled_addr ;

always @ (posedge clk_4M ) begin
    
    if ( rd_n == 0 ) begin
        // read program rom
        if ( cpu_addr >= 16'h0000 && cpu_addr < 16'h2000 ) begin
            cpu_din <= cpu01rom_data ; // 0x0000
            
        end else if ( cpu_addr >= 16'h2000 && cpu_addr < 16'h4000 ) begin    
            cpu_din <= cpu02rom_data ; // 0x2000
            
        end else if ( cpu_addr >= 16'h4000 && cpu_addr < 16'h6000 ) begin               
            cpu_din <= cpu03rom_data ; // 0x4000
            
        end else if ( cpu_addr >= 16'h6000 && cpu_addr < 16'h8000 ) begin                   
            cpu_din <= cpu04rom_data ; // 0x6000
            
        end else if ( cpu_addr >= 16'h8000 && cpu_addr < 16'h8400 ) begin   
            cpu_din <= bg_ram0_data;
            
        end else if ( cpu_addr >= 16'h8400 && cpu_addr < 16'h8800 ) begin    
            cpu_din <= bg_ram1_data;
            
        end else if ( cpu_addr >= 16'h8800 && cpu_addr < 16'h8c00 ) begin   
            cpu_din <= fg_ram0_data;
            
        end else if ( cpu_addr >= 16'h8c00 && cpu_addr < 16'h9000 ) begin   
            cpu_din <= fg_ram1_data;

        end else if ( cpu_addr == 16'h9803 ) begin   
            cpu_din <= u001_dout;
            
        end else if ( cpu_addr == 16'ha000 ) begin   
            cpu_din <= p1;
            
        end else if ( cpu_addr == 16'ha001 ) begin
            cpu_din <= p2;
            
        end else if ( cpu_addr == 16'ha002 ) begin   
            cpu_din <= dsw1;
            
        end else if ( cpu_addr == 16'ha003 ) begin           
            cpu_din <= dsw2;
            
        end else if ( cpu_addr >= 16'he000 && cpu_addr < 16'hf000 ) begin   
            cpu_din <= cpu_ram_data;
            
        end else begin
            unhandled_addr <= cpu_addr;
        end
    end else begin
    
        if ( cpu_addr[15:12] == 4'he ) begin
            // 0xe000-0xefff z80 ram
            cpu_ram_w <= ~wr_n ;
        end else if ( cpu_addr[15:12] == 4'h8 ) begin
                case ( cpu_addr[11:10] )
                    6'b00 :  gfx_bg_ram0_wr <= ~wr_n;
                    6'b01 :  gfx_bg_ram1_wr <= ~wr_n;
                    6'b10 :  gfx_fg_ram0_wr <= ~wr_n;
                    6'b11 :  gfx_fg_ram1_wr <= ~wr_n;
                endcase 
        end else if (cpu_addr >= 16'h9000 && cpu_addr < 16'h9800 ) begin 
            // 0x9000-0x90ff sprite ram
            if ( ~vbl ) begin
                spr_ram_wr <=  ~wr_n ;
            end
        end else if (cpu_addr[15:11] == 5'b11111 ) begin 
            // 0xF800-0xffff horz scroll latch
            if ( wr_n == 0 ) begin
                bg_scroll_y <= cpu_dout;
            end
        end else if (cpu_addr == 16'h9800 ) begin         
            if ( wr_n == 0 ) begin
                cocktail_flip <= cpu_dout[0];
            end
        end else if (cpu_addr == 16'h9801 ) begin 
            sound1_wr <= ~wr_n;
            sound1_en <= 1;
        end else if (cpu_addr == 16'h9802 ) begin 
            sound2_wr <= ~wr_n;
            sound2_en <= 1;        
        end else begin
            // no valid write address
            cpu_ram_w <= 0 ;
            
            gfx_fg_ram0_wr <= 0 ;
            gfx_fg_ram1_wr <= 0 ;
            
            gfx_bg_ram0_wr <= 0 ;
            gfx_bg_ram1_wr <= 0 ;
            
            sound1_wr <= 0;
            sound1_en <= 0;    

            sound2_wr <= 0;
            sound2_en <= 0;    
        end
    end
end

// u001 "secret" pal protection
// cpu tries to read val from 0x9803 which is state machine pal
// written to on all tile ram access. 

wire [7:0] u001_dout ;

secret_pal u001
(
	.clk( gfx_fg_ram0_wr | gfx_fg_ram1_wr),
	.i( cpu_dout ),
	.o( u001_dout )
);


// first 256 bytes are attribute data
// bit 7 of attr == MSB of tile 
// bit 6 tile flip
// bit 5-0 == 64 colors from palette
// bytes 256-511 are tile index

    
wire wr_n;
wire rd_n;

// interupt control 
// the irq should be clocked by the risign vbl and cleared by
// IORQ_n and M1_n both low for Z80 IRQ ack, 
// by the interrupt request clear signal from the video gen, 
// or by a 555 watchdog.  This should be fixed.

wire IORQ_n;
wire M1_n;

reg prev_vbl = 0;
reg vert_int_n;

//always @ (posedge clk_4M ) begin
//    prev_vbl <= vbl;
//    if ( prev_vbl == 0 && vbl == 1 ) begin
//        vert_int_n <= 0;
//    end else if ( ( IORQ_n == 0 && M1_n == 0 ) || ( vbl == 0 && v == 32 ) ) begin
//        // 
//        vert_int_n <= 1;
//    end
//end

always @ (posedge clk_4M ) begin
    prev_vbl <= vbl;
    vert_int_n <= ( v !== 208 ) ;
end

   
T80pa u_cpu(
    .RESET_n    ( ~reset ),
    .CLK        ( clk_8M ),
    .CEN_p      ( clk_4M ),     
    .CEN_n      ( 1'b1 ),
    .WAIT_n     ( ~pause_cpu ),
    .INT_n      ( vert_int_n ),  
    .NMI_n      ( 1'b1     ),
    .BUSRQ_n    ( 1'b1     ),
    .RD_n       ( rd_n     ),
    .WR_n       ( wr_n     ),
    .A          ( cpu_addr ),
    .DI         ( cpu_din  ),
    .DO         ( cpu_dout ),
    // unused
    .DIRSET     ( 1'b0     ),
    .DIR        ( 212'b0   ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     (IORQ_n),
    .M1_n       (M1_n),
    .BUSAK_n    (),
    .HALT_n     (),
    .MREQ_n     (),
    .Stop       (),
    .REG        ()
);

reg [7:0] sound1_out;
reg [7:0] sound2_out;
wire [8:0] sound_mix = sound1_out + sound2_out;

reg sound1_wr;
reg sound1_en ;

reg sound2_wr;
reg sound2_en ;

// Mr. Do is not stereo.  Sound should be added together and /2. 

assign AUDIO_L = {sound_mix[8:1],sound_mix[8:1]};
assign AUDIO_R = {sound_mix[8:1],sound_mix[8:1]};

assign AUDIO_S = 0; // unsigned PCM

wire [3:0] sound_mask = pause_cpu ? 4'b0000 : 4'b1111;

// sound clock, cpu clock, chip select, write enable, data, mask, output )
SN76496 sound1( clk_4M, clk_4M, reset, sound1_en, sound1_wr, cpu_dout, sound_mask, sound1_out );
SN76496 sound2( clk_4M, clk_4M, reset, sound2_en, sound2_wr, cpu_dout, sound_mask, sound2_out );


// cpu rom C4
wire a4_cs = (ioctl_addr[15:13] == 3'b000);

rom_8k	cpu01rom_a4 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[12:0] ),
	.wren ( ioctl_wr & a4_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_4M ),
	.rdaddress ( cpu_addr[12:0] ),
	.q ( cpu01rom_data )
	);

// cpu rom C4
wire c4_cs = (ioctl_addr[15:13] == 3'b001);

rom_8k	cpu01rom_c4 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[12:0] ),
	.wren ( ioctl_wr & c4_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_4M ),
	.rdaddress ( cpu_addr[12:0] ),
	.q ( cpu02rom_data )
	);
   
// cpu rom E4
wire e4_cs = (ioctl_addr[15:13] == 3'b010);

rom_8k	cpu01rom_e4 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[12:0] ),
	.wren ( ioctl_wr & e4_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_4M ),
	.rdaddress ( cpu_addr[12:0] ),
	.q ( cpu03rom_data )
	);
    
// cpu rom F4
wire f4_cs = (ioctl_addr[15:13] == 3'b011);

rom_8k	cpu01rom_f4 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[12:0] ),
	.wren ( ioctl_wr & f4_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_4M ),
	.rdaddress ( cpu_addr[12:0] ),
	.q ( cpu04rom_data )
	);
    
    
ram_dp_4k    cpu_ram_inst (    
    .address_a ( cpu_addr[11:0] ),
    .clock_a ( ~clk_4M ),
    .data_a ( cpu_dout ),
    .wren_a ( cpu_ram_w ),
    .q_a ( cpu_ram_data ),

    .address_b ( hs_address ),
    .clock_b ( clk_sys ),
    .data_b ( hs_data_in ),
    .wren_b ( hs_write_enable ),
    .q_b ( hs_data_out )
    );

// foreground tile attributes
ram_dp_1k gfx_fg_ram0_inst (
	.clock_a ( ~clk_5M ),
	.address_a ( cpu_addr[9:0] ),
	.data_a ( cpu_dout ),
	.wren_a ( gfx_fg_ram0_wr ),
	.q_a ( fg_ram0_data ),

	.clock_b ( ~clk_10M ),
	.address_b ( fg_char_index ),
	.data_b ( 0 ),
	.wren_b ( 0 ),
	.q_b ( gfx_fg_attr_data )
	);

// foreground tile index
ram_dp_1k gfx_fg_ram1_inst (
	.clock_a ( ~clk_4M ),
	.address_a ( cpu_addr[9:0] ),
	.data_a ( cpu_dout ),
	.wren_a ( gfx_fg_ram1_wr ),
	.q_a ( fg_ram1_data ),

	.clock_b ( ~clk_10M ),
	.address_b ( fg_char_index ),
	.data_b ( 0 ),
	.wren_b ( 0 ),
	.q_b ( gfx_fg_tile_data )
	);
    
// background tile attributes    
ram_dp_1k gfx_bg_ram0_inst (
	.clock_a ( ~clk_4M ),
	.address_a ( cpu_addr[9:0] ),
	.data_a ( cpu_dout ),
	.wren_a ( gfx_bg_ram0_wr ),
	.q_a ( bg_ram0_data ),

	.clock_b ( ~clk_10M ),
	.address_b ( bg_char_index ),
	.data_b ( 0 ),
	.wren_b ( 0 ),
	.q_b ( gfx_bg_attr_data )
	);
    
// background tile index    
ram_dp_1k gfx_bg_ram1_inst (
	.clock_a ( ~clk_4M ),
	.address_a ( cpu_addr[9:0] ),
	.data_a ( cpu_dout ),
	.wren_a ( gfx_bg_ram1_wr ),
	.q_a ( bg_ram1_data ),

	.clock_b ( ~clk_10M ),
	.address_b ( bg_char_index ),
	.data_b ( 0 ),
	.wren_b ( 0 ),
	.q_b ( gfx_bg_tile_data )
	);
    
// sprite ram - hardware uses 2x6148 = 1k, only 256 bytes can be addressed
ram_dp_1k spr_ram (
	.clock_a ( ~clk_4M ),
	.address_a ( { 2'b00, cpu_addr[7:0] } ),
	.data_a ( cpu_dout ),
	.wren_a ( spr_ram_wr ),
//	.q_a ( ), // cpu can't read sprite ram

	.clock_b ( ~clk_10M ),
	.address_b ( spr_addr ),
	.data_b ( 0 ),
	.wren_b ( 0 ),
	.q_b ( spr_ram_data )
	);
    
// foreground tile bitmap S8   
wire s8_cs = (ioctl_addr[15:12] == 4'b1000);

   
rom_4k gfx_s8 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & s8_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( fg_bitmap_addr ),
	.q ( s8_data )
	);

// foreground tile bitmap u8  
wire u8_cs = (ioctl_addr[15:12] == 4'b1001);

rom_4k gfx_u8 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & u8_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( fg_bitmap_addr ),
	.q ( u8_data )
	);

    
// background tile bitmap r8
wire r8_cs = (ioctl_addr[15:12] == 4'b1010);

rom_4k gfx_r8 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & r8_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( bg_bitmap_addr ),
	.q ( r8_data )
	);
    
    
// background tile bitmap n8
wire n8_cs = (ioctl_addr[15:12] == 4'b1011);

rom_4k gfx_n8 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & n8_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( bg_bitmap_addr ),
	.q ( n8_data )
	);
    
// sprite bitmap h5
wire h5_cs = (ioctl_addr[15:12] == 4'b1100);

rom_4k gfx_h5 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & h5_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( spr_bitmap_addr ),
	.q ( h5_data )
	);

// sprite bitmap k5
wire k5_cs = (ioctl_addr[15:12] == 4'b1101);

rom_4k gfx_k5 (
	.wrclock ( clk_sys ),
	.wraddress ( ioctl_addr[11:0] ),
	.wren ( ioctl_wr & k5_cs & rom_download ),
	.data ( ioctl_dout ),

	.rdclock ( ~clk_10M ),
	.rdaddress ( spr_bitmap_addr ),
	.q ( k5_data )
	);
    
// palette high bits
wire u02_cs = (ioctl_addr[15:5] == 11'b11100000000 );

rom_32b	pal_rom_u2 (
	.wrclock ( clk_sys ),
	.wren ( ioctl_wr & u02_cs & rom_download ),
	.wraddress ( ioctl_addr[4:0] ),
	.data ( ioctl_dout ),
    
	.rdclock ( ~clk_10M ),
	.rdaddress ( fg_pal_ofs_hi ),
	.q ( fg_pal_data_high )
	);


// palette low bits
wire t02_cs = (ioctl_addr[15:5] == 11'b11100000001 );

rom_32b	pal_rom_t2 (
	.wrclock ( clk_sys ),
	.wren ( ioctl_wr & t02_cs & rom_download ),
	.wraddress ( ioctl_addr[4:0] ),
	.data ( ioctl_dout ),
    
	.rdclock ( ~clk_10M ),
	.rdaddress ( fg_pal_ofs_low ),
	.q ( fg_pal_data_low )
	);
    
// sprite palette lookup F10
wire f10_cs = (ioctl_addr[15:5] == 11'b11100000010 );

rom_32b	pal_rom_f10 (
	.wrclock ( clk_sys ),
	.wren ( ioctl_wr & f10_cs & rom_download ),
	.wraddress ( ioctl_addr[4:0] ),
	.data ( ioctl_dout ),
    
	.rdclock ( ~clk_10M ),
	.rdaddress ( f10_addr ),
	.q ( f10_data )
	);


// HISCORE SYSTEM
// --------------
wire [11:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(12),
	.CFG_ADDRESSWIDTH(3),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(),
	.ram_intent_write(),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

endmodule

