//============================================================================
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
//============================================================================

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

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
assign AUDIO_L = audio;
assign AUDIO_R = AUDIO_L;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

wire [127:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire		scandoubler_disable;
wire        ypbpr;
wire        ps2_kbd_clk, ps2_kbd_data;
wire  		audio;
wire 		hs, vs;
wire 		vid_play, vid_RP, vid_LP, vid_Ball;
reg   [7:0] gameSelect = 7'b0000001; //Default to Tennis

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"TVFun;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[2],TV Mode,NTSC,PAL;",
	//"O[4:3],Noise,White,Red,Green,Blue;",
	"-;",
	"O[11:5],Game,Tennis,Soccer,Handicap,Squash,Practice,Rifle1,Rifle2;", //[13]
	"O[12],Serve		,Manual,Auto;", //[4]
	"O[13],Ball Angle	,20deg,40deg;", //check  [5]
	"O[14],Bat Size	,Small,Big;",	//check [6]
	"O[15],Ball Speed	,Fast,Slow;", //check  [7]
	"O[16],Invisiball,OFF,ON;",  //[8]
	"O[25:17],Color Palette,Mono,Greyscale,RGB1,RGB2,Field,Ice,Christmas,Marksman,Las Vegas;", //[9C]  [25:17]
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"V,v",`BUILD_DATE 
};


wire [6:0] game_mode = status[11:5];
wire [8:0] palette = status[25:17];

wire forced_scandoubler;
wire  [10:0] ps2_key;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_16M),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	
	.ps2_key(ps2_key)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Clocks

wire clk_16M, clk_2M;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_16M),
	.outclk_1(clk_2M)
);

wire reset = RESET | status[0] | buttons[1];

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

ay38500NTSC ay38500NTSC(
	.clk(clk_2M),
	.superclock(CLK_50M),
	.reset(reset),
	//.reset(~(buttons[1] | status[0])),

	.pinSound(audio),

	//Video
	.pinBallOut(vid_Ball),
	.pinRPout(vid_RP),
	.pinLPout(vid_LP),
	.pinSFout(vid_play),	
	.syncV(VSync),
    .syncH(HSync),

	//Menu Items
	.pinManualServe(~(status[12] | m_fireA | m_fire2A)), // was 4
	.pinBallAngle(status[13]), // was 5
	.pinBatSize(status[14]), // was 6
	.pinBallSpeed(status[15]), // was 7

	//Game Select
	.pinPractice(!gameSelect[4:4]),
	.pinSquash(!gameSelect[3:3]),
	.pinSoccer(!gameSelect[1:1]),
	.pinTennis(!gameSelect[0:0]),
	.pinRifle1(!gameSelect[5:5]),
	.pinRifle2(!gameSelect[6:6]),
	
	.pinHitIn(hitIn),
	.pinShotIn(shotIn),
	.pinLPin(LPin),
	.pinRPin(RPin)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VIDEO

wire HSync;
wire VSync;
wire ce_pix;

assign CLK_VIDEO = clk_16M;
assign ce_pix = 1'b1;

reg [12:0] colorOut = 0;
always @(posedge clk_16M) begin
	if(vid_Ball & showBall) begin
		case(palette)		
		//case(status[13:9])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'hF00;//RGB1
			'h3: colorOut <= 12'hFFF;//RGB2
			'h4: colorOut <= 12'h000;//Field
			'h5: colorOut <= 12'h000;//Ice
			'h6: colorOut <= 12'hFFF;//Christmas
			'h7: colorOut <= 12'hFFF;//Marksman
			'h8: colorOut <= 12'hFF0;//Las Vegas
		endcase
	end
	else if(vid_LP) begin
		case(palette)		
		//case(status[13:9])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'h0F0;//RGB1
			'h3: colorOut <= 12'h00F;//RGB2
			'h4: colorOut <= 12'hF00;//Field
			'h5: colorOut <= 12'hF00;//Ice
			'h6: colorOut <= 12'hF00;//Christmas
			'h7: colorOut <= 12'hFF0;//Marksman
			'h8: colorOut <= 12'hFF0;//Las Vegas
		endcase
	end
	else if(vid_RP) begin
		case(palette)		
		//case(status[13:9])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'h000;//Greyscale
			'h2: colorOut <= 12'h0F0;//RGB1
			'h3: colorOut <= 12'hF00;//RGB2
			'h4: colorOut <= 12'h00F;//Field
			'h5: colorOut <= 12'h030;//Ice
			'h6: colorOut <= 12'h030;//Christmas
			'h7: colorOut <= 12'h000;//Marksman
			'h8: colorOut <= 12'hF0F;//Las Vegas
		endcase
	end
	else if(vid_play) begin
		case(palette)		
		//case(status[13:9])
			'h0: colorOut <= 12'hFFF;//Mono
			'h1: colorOut <= 12'hFFF;//Greyscale
			'h2: colorOut <= 12'h00F;//RGB1
			'h3: colorOut <= 12'h0F0;//RGB2
			'h4: colorOut <= 12'hFFF;//Field
			'h5: colorOut <= 12'h55F;//Ice
			'h6: colorOut <= 12'hFFF;//Christmas
			'h7: colorOut <= 12'hFFF;//Marksman
			'h8: colorOut <= 12'hF90;//Las Vegas
		endcase
	end
	else begin
		case(palette)		
		//case(status[13:9])
			'h0: colorOut <= 12'h000;//Mono
			'h1: colorOut <= 12'h999;//Greyscale
			'h2: colorOut <= 12'h000;//RGB1
			'h3: colorOut <= 12'h000;//RGB2
			'h4: colorOut <= 12'h4F4;//Field
			'h5: colorOut <= 12'hCCF;//Ice
			'h6: colorOut <= 12'h000;//Christmas
			'h7: colorOut <= 12'h0D0;//Marksman
			'h8: colorOut <= 12'h000;//Las Vegas
		endcase
	end
end

video_mixer #(.GAMMA(0)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.ce_pix(ce_pix),
	.CE_PIXEL(CE_PIXEL),

	.scandoubler(),
	.hq2x(), 	   
	.gamma_bus(),
	.HDMI_FREEZE(),
	.freeze_sync(),

	.R(colorOut[11:8]),
	.G(colorOut[7:4]),
	.B(colorOut[3:0]),

	.HSync(HSync),
	.VSync(VSync),
	//.HSync(~HSync),
	//.VSync(~VSync),	
	.HBlank(HBlank),
	.VBlank(VBlank),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Game Select

always @(clk_16M) begin
 case(game_mode)
 //case (status[3:1])
	3'b000  : gameSelect = 7'b0000001; //Tennis
	3'b001  : gameSelect = 7'b0000010; //Soccer
	3'b010  : gameSelect = 7'b0000100; //Handicap (using a dummy bit)
	3'b011  : gameSelect = 7'b0001000; //Squash
	3'b100  : gameSelect = 7'b0010000; //Practice
	3'b101  : gameSelect = 7'b0100000; //Rifle 1
	3'b110  : gameSelect = 7'b1000000; //Rifle 1
	default : gameSelect = 7'b0000001; //Tennis
 endcase
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Paddle Emulation

wire [4:0] paddleMoveSpeed = status[15] ? 8 : 5;//Faster paddle movement when ball speed is high   //was 7
reg [8:0] player1pos = 8'd128;
reg [8:0] player2pos = 8'd128;
reg [8:0] player1cap = 0;
reg [8:0] player2cap = 0;
reg hsOld = 0;
reg vsOld = 0;

always @(posedge clk_16M) begin
	hsOld <= HSync;
	vsOld <= VSync;
	if(VSync & !vsOld) begin
		player1cap <= player1pos;
		player2cap <= player2pos;
		if(m_up & player1pos>0)
			player1pos <= player1pos - paddleMoveSpeed;
		else if(m_down & player1pos<8'hFF)
			player1pos <= player1pos + paddleMoveSpeed;
		if(m_up2 & player2pos>0)
			player2pos <= player2pos - paddleMoveSpeed;
		else if(m_down2 & player2pos < 8'hFF)
			player2pos <= player2pos + paddleMoveSpeed;
	end
	else if(HSync & !hsOld) begin
		if(player1cap!=0)
			player1cap <= player1cap - 1;
		if(player2cap!=0)
			player2cap <= player2cap - 1;
	end
end

//wire [3:0] r,g,b;
wire HBlank = !HSync;
wire VBlank = !VSync;
wire showBall = !status[16] | (ballHide>0); // was 8
reg [5:0] ballHide = 0;
reg audioOld = 0;
always @(clk_16M) begin
	audioOld <= audio;
	if(!audioOld & audio)
		ballHide <= 5'h1F;
	else if(VSync & !vsOld & ballHide!=0)
		ballHide <= ballHide - 1;
end

wire hitIn;// = (gameBtns[5:5] | gameBtns[6:6]) ? btnHit : audio;
//Still unknown why example schematic instructs connecting hitIn pin to audio during ball games
wire shotIn;// = (gameBtns[5:5] | gameBtns[6:6]) ? (btnHit | btnMiss) : 1;
wire LPin = (player1cap == 0);
wire RPin = (player2cap == 0);

wire ltest;

/*
dac #(
	.c_bits(16))
dac (
	.clk_i			(clk_16M	   ),
	.res_n_i		(1			   ),
	.dac_i			({audio, 15'b0}),
	.dac_o			(AUDIO_L	   )
	);
*/

wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

/*
arcade_inputs inputs (
        .clk         ( clk_16M     ),
        .key_strobe  ( key_strobe  ),
        .key_pressed ( key_pressed ),
        .key_code    ( key_code    ),
        .joystick_0  ( joystick_0  ),
        .joystick_1  ( joystick_1  ),
        .rotate      ( 1'b0        ),
        .orientation ( 2'b10       ),
        .joyswap     ( 1'b0        ),
        .oneplayer   ( 1'b0        ),
        .controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
        .player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
        .player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);
*/

endmodule 