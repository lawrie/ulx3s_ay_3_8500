`default_nettype none
module top (
  input         clk25_mhz,
  // Buttons
  input [6:0]   btn,
  // VGA
  output [3:0]  red,
  output [3:0]  green,
  output [3:0]  blue,
  output        hSync,
  output        vSync,
  // HDMI
  output [3:0]  gpdi_dp,
  output [3:0]  gpdi_dn,
  // Keyboard
  output        usb_fpga_pu_dp,
  output        usb_fpga_pu_dn,
  input         ps2Clk,
  input         ps2Data,
  // Audio
  output [3:0]  audio_l,
  output [3:0]  audio_r,

  output [7:0]  leds
);

// Pull-ups for us2 connector
assign usb_fpga_pu_dp = 1;
assign usb_fpga_pu_dn = 1;

// Generate a 48 Mhz clock
wire clk_sys;

pll pll_i (
  .clkin(clk25_mhz),
  .clkout0(clk_sys)
);

// Generate 2Mhz and 6Mhz clock enable signals for video
reg [5:0] div6;
reg [2:0] div3;
reg ce_2m;
reg ce_6m;

always @(posedge clk_sys) begin
  div6 <= div6 + 1'd1;
  if(div6 == 23) div6 <= 0;

  ce_2m <= !div6;
end

always @(posedge clk_sys) begin
  div3 <= div3 + 1'd1;
  ce_6m <= !div3;
end

// Options
wire angle = 1;
wire size = 1;
wire speed = 0;
wire autoserve = 1;

//   0 : Mystery game
//   1 : Tennis
//   2 : Soccer
//   3 : Handicap
//   4 : Squash
//   5 : Practice
//   6 : Rifle 1
//   7 : Rifle 2
reg [7:0] gameSelect = 1;

// Vertical position of player on 256x256 field
reg [8:0] player1pos = 8'd128;
reg [8:0] player2pos = 8'd128;

// Simulation of Atari paddle capacitors
reg [8:0] player1cap = 0;
reg [8:0] player2cap = 0;

// Color Palletes:
//
//   0 - Mono: Solid black/white, most systems did this
//   1 - Greyscale: Achieved using external resistors in real systems
//   2 - RGB1: Arbitrary pallete used during development
//   3 - RGB2: Based on video of an actual console (forgot which one)
//   4 - Field: Approximation of a grass-colored field
//   5 - Ice: Approximation of an ice rink
//   6 - Christmas: Mono with red/green paddles
//   7 - Marksman: Based on footage of the Coleco Telstar Marksman
//   8 - Las Vegas: Based on footage of Tele-spiel Las Vegas
reg [3:0]  colorOption = 0;

// Inputs
wire [10:0] ps2_key;
wire        pressed = ~ps2_key[9];
wire [7:0]  code    = ps2_key[7:0];

// Joystick not implemented
wire [15:0] joy0 = 0,joy1 = 0;
wire [15:0] joystick_analog_0 = 0;
wire [15:0] joystick_analog_1 = 0;

// Paddle positions - not implemented
wire  [7:0] paddle_0 = 0;
wire  [7:0] paddle_1 = 0;

// Button inputs
reg btnP1Up = 0;
reg btnP1Down = 0;
reg btnP2Up = 0;
reg btnP2Down = 0;
reg btnServe = 0;

// Show button state on leds
assign leds = {btnP1Up, btnP1Down, btnP2Up, btnP2Down, btnServe};

// Input options - default to keyboard
reg [1:0] p1Option = 0;
reg       p1Invert = 0;
reg [1:0] p2Option = 0;
reg       p2Invert = 0;

// Keyboard inputs:
//
//   R       : Reset
//   W/S     : Player 1 up/down
//   UP/DOWN : Player 1 up/down
//   SPACE   : Serve Ball
//   V       : Toggle Manual Serve
//   C       : Toggle Paddle Size
//   X       : Toggle Ball Speed
//   Z       : Toggle Ball Angle
always @(posedge clk_sys) begin
  if(ps2_key[10]) begin
    case(code)
      'h1D: btnP1Up   <= pressed; // W
      'h1B: btnP1Down <= pressed; // S
      'h75: btnP2Up   <= pressed; // up
      'h72: btnP2Down <= pressed; // down
      'h29: btnServe  <= pressed; // space
    endcase
  end
end

// Get PS/2 keyboard events
ps2 ps2_kbd (
  .clk(clk_sys),
  .ps2_clk(ps2Clk),
  .ps2_data(ps2Data),
  .ps2_key(ps2_key)
);

/////////////////Paddle Emulation//////////////////
wire [4:0] paddleMoveSpeed = speed ? 5'd8 : 5'd5;//Faster paddle movement when ball speed is high
reg hsOld = 0;
reg vsOld = 0;

always @(posedge clk_sys) begin
  hsOld <= hs;
  vsOld <= vs;
  if(vs & !vsOld) begin
    if(!p1Option) begin
      player1cap <= player1pos ^ {8{p1Invert}};

      if(btnP1Up   | joy0[3]) 
	player1pos <= ((player1pos - paddleMoveSpeed) > 255) ? 9'd0   : (player1pos - paddleMoveSpeed);
      if(btnP1Down | joy0[2]) 
	player1pos <= ((player1pos + paddleMoveSpeed) > 255) ? 9'd255 : (player1pos + paddleMoveSpeed);
    end else if(~p1Option[1]) begin
      player1cap <= {~joystick_analog_0[15],joystick_analog_0[14:8]} ^ {8{p1Invert}};
    end else if(~p1Option[0]) begin
      player1cap <= {~joystick_analog_0[7],joystick_analog_0[6:0]} ^ {8{p1Invert}};
    end else begin
      player1cap <= paddle_0 ^ {8{p1Invert}};
    end

    if(!p2Option) begin
      player2cap <= player2pos ^ {8{p2Invert}};

      if(btnP2Up   | joy1[3]) 
	player2pos <= ((player2pos - paddleMoveSpeed) > 255) ? 9'd0   : (player2pos - paddleMoveSpeed);
      if(btnP2Down | joy1[2]) 
        player2pos <= ((player2pos + paddleMoveSpeed) > 255) ? 9'd255 : (player2pos + paddleMoveSpeed);
    end else if(~p2Option[1]) begin
      player2cap <= {~joystick_analog_1[15],joystick_analog_1[14:8]} ^ {8{p2Invert}};
    end else if(~p2Option[0]) begin
      player2cap <= {~joystick_analog_1[7],joystick_analog_1[6:0]} ^ {8{p2Invert}};
    end else begin
      player2cap <= paddle_1 ^ {8{p2Invert}};
    end
  end else if(hs & !hsOld) begin
    if(player1cap!=0) player1cap <= player1cap - 9'd1;
    if(player2cap!=0) player2cap <= player2cap - 9'd1;
  end
end

// Signal outputs (active-high except for sync)
wire audio;
wire rpOut;
wire lpOut;
wire ballOut;
wire scorefieldOut;
wire syncH;
wire syncV;
wire isBlanking;

// Input signals from simulated capacitors
wire lpIN = (player1cap == 0);
wire rpIN = (player2cap == 0);

// Reset
wire chipReset = !btn[0];

// The AY 3 8500 chip
ay38500NTSC the_chip
(
  .superclock(clk_sys),
  .clk(ce_2m),
  .reset(!chipReset),
  .pinRPout(rpOut),
  .pinLPout(lpOut),
  .pinBallOut(ballOut),
  .pinSFout(scorefieldOut),
  .syncH(syncH),
  .syncV(syncV),
  .pinSound(audio),
  .pinManualServe(!(autoserve | btnServe)),
  .pinBallAngle(!angle),
  .pinBatSize(!size),
  .pinBallSpeed(!speed),
  .pinPractice(!gameSelect[4]),
  .pinSquash(!gameSelect[3]),
  .pinSoccer(!gameSelect[1]),
  .pinTennis(!gameSelect[0]),
  .pinRifle1(!gameSelect[5]),
  .pinRifle2(!gameSelect[6]),
  .pinHitIn(audio),
  .pinShotIn(1),
  .pinLPin(lpIN),
  .pinRPin(gameSelect[4] ? lpIN : rpIN)
);

/////////////////////VIDEO//////////////////////
wire hs = !syncH;
wire vs = !syncV;
wire [3:0] r,g,b;
wire showBall = (ballHide>0);
reg [5:0] ballHide = 0;
reg audioOld = 0;

// Ball hiding logic
always @(posedge clk_sys) begin
  audioOld <= audio;
  if(!audioOld & audio)
    ballHide <= 5'h1F;
  else if(vs & !vsOld & ballHide!=0)
    ballHide <= ballHide - 1'd1;
end

// Allocate colors to different elements
reg [11:0] colorOut;

always @(posedge clk_sys) begin
  if(ballOut & showBall) begin
    case(colorOption)
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
  end else if(lpOut) begin
    case(colorOption)
      'h0: colorOut <= 12'hFFF;//Mono
      'h1: colorOut <= 12'hFFF;//Greyscale
      'h2: colorOut <= 12'h0F0;//RGB1
      'h3: colorOut <= 12'h00F;//RGB
      'h4: colorOut <= 12'hF00;//Field
      'h5: colorOut <= 12'hF00;//Ice
      'h6: colorOut <= 12'hF00;//Christmas
      'h7: colorOut <= 12'hFF0;//Marksman
      'h8: colorOut <= 12'hFF0;//Las Vegas
    endcase
  end else if(rpOut) begin
    case(colorOption)
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
  end else if(scorefieldOut) begin
    case(colorOption)
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
  end else begin
    case(colorOption)
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

// Calculate blank signals
reg HBlank, VBlank;
reg [10:0] hcnt, vcnt;
reg old_hs, old_vs;

always @(posedge clk_sys) begin
  if (ce_2m) begin
    hcnt <= hcnt + 1'd1;
    old_hs <= syncH;
    if(old_hs & ~syncH) begin
      hcnt <= 0;

      vcnt <= vcnt + 1'd1;
      old_vs <= syncV;
      if(old_vs & ~syncV) vcnt <= 0;
    end
     
    if (hcnt == 21)  HBlank <= 0;
    if (hcnt == 100) HBlank <= 1;

    if (vcnt == 34)  VBlank <= 0;
    if (vcnt == 240) VBlank <= 1;
  end
end

// Double the NTSC signal to VGA
scandoubler #(.HALF_DEPTH(1)) sd (
  .clk_vid(clk_sys),
  .ce_pix(ce_6m),
  .hs_in(syncH),
  .vs_in(syncV),
  .hb_in(HBlank),
  .vb_in(VBlank),
  .r_in(colorOut[11:8]),
  .g_in(colorOut[7:4]),
  .b_in(colorOut[3:0]),
  .hs_out(hSync),
  .vs_out(vSync),
  .r_out(red),
  .g_out(green),
  .b_out(blue)
);

// Audio output
assign audio_l = {4{audio}};
assign audio_r = {4{audio}};

endmodule
