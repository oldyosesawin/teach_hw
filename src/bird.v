/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // 1. LEAVE IT THERE!

  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  assign uo_out = {
    hsync, B[0], G[0], R[0],
    vsync, B[1], G[1], R[1]
  };

  assign uio_out = 0;
  assign uio_oe = 0;

  wire _unused_ok = &{ena, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // 2. game setting

  localparam BIRD_X = 150;
  localparam PIPE_WIDTH = 55;
  localparam GAP_SIZE = 125;
  localparam GROUND_Y = 440;

  // Bird position and movement
  reg signed [15:0] bird_y;
  reg signed [8:0] bird_velocity;

  // Pipe position
  reg [9:0] pipe_x;
  reg [9:0] gap_center;

  // Score
  reg [3:0] score;

  // Game states
  reg game_started;
  reg game_over;

  // Button detection
  reg button_prev;
  reg restart_prev;


  // 3. Pipe and bird positions

  wire [9:0] gap_top = gap_center - GAP_SIZE/2;
  wire [9:0] gap_bottom = gap_center + GAP_SIZE/2;

  wire [9:0] bird_top = bird_y - 11'sd8;
  wire [9:0] bird_bottom = bird_y + 11'sd8;

  wire signed [10:0] gap_top_s =
      $signed({1'b0, gap_top});

  wire signed [10:0] gap_bottom_s =
      $signed({1'b0, gap_bottom});


  // 4. Logic of the game systems


  always @(posedge vsync or negedge rst_n) begin

    if (!rst_n) begin

      bird_y <= 240;
      bird_velocity <= 0;

      pipe_x <= 640;
      gap_center <= 220;

      score <= 0;

      game_started <= 0;
      game_over <= 0;

      button_prev <= 0;
      restart_prev <= 0;

    end

    else begin

      // Remember previous button states
      button_prev <= ui_in[0];
      restart_prev <= ui_in[1];


      // Restart the games
  

      if (game_over) begin

        if (ui_in[1] && !restart_prev) begin

          bird_y <= 240;
          bird_velocity <= 0;

          pipe_x <= 640;
          gap_center <= 220;

          score <= 0;

          game_started <= 0;
          game_over <= 0;

        end

      end


      // Start


      else if (!game_started) begin

        if (ui_in[0] && !button_prev) begin

          game_started <= 1;
          bird_velocity <= -9;

        end

      end

      // Main game systems

      else begin

        // Bird movements

        if (ui_in[0] && !button_prev) begin

          bird_velocity <= -9;

        end

        else if (bird_velocity < 8) begin

          bird_velocity <= bird_velocity + 1;

        end

        bird_y <= bird_y + bird_velocity;

        // Pipe movements

        if (pipe_x <= 3) begin

          pipe_x <= 640;

          if (gap_center == 220)
            gap_center <= 300;
          else
            gap_center <= 220;

        end

        else begin

          pipe_x <= pipe_x - 3;

        end


        //Hibox of the ground / top of the boxs

        if (bird_y >= GROUND_Y - 8 ||
            bird_y <= 8) begin

          game_over <= 1;

        end

        //Hitbox of the pipe

        if (pipe_x < BIRD_X + 10 &&
            pipe_x + PIPE_WIDTH > BIRD_X - 10) begin

          if (bird_y - 11'sd8 < gap_top_s ||
              bird_y + 11'sd8 > gap_bottom_s) begin

            game_over <= 1;

          end

        end

      end

    end

  end

  // 6. Create game object
  reg [1:0] red;
  reg [1:0] green;
  reg [1:0] blue;

  // Bird beak
  wire bird_beak =
      pix_x >= BIRD_X + 10 &&
      pix_x <= BIRD_X + 15 &&
      pix_y >= bird_y - 11'sd2 &&
      pix_y <= bird_y + 11'sd2;

  // Bird body
  wire bird_body =
      pix_x >= BIRD_X - 10 &&
      pix_x <= BIRD_X + 10 &&
      pix_y >= bird_top &&
      pix_y <= bird_bottom;

  // Pipe body
  wire pipe_horizontal =
      pix_x >= pipe_x &&
      pix_x < pipe_x + PIPE_WIDTH;

  wire top_pipe =
      pipe_horizontal &&
      pix_y < gap_top &&
      pix_y < GROUND_Y;

  wire bottom_pipe =
      pipe_horizontal &&
      pix_y > gap_bottom &&
      pix_y < GROUND_Y;

  // Pipe caps
  wire pipe_cap_horizontal =
      pix_x >= pipe_x - 5 &&
      pix_x < pipe_x + PIPE_WIDTH + 5;

  wire top_cap =
      pipe_cap_horizontal &&
      pix_y >= gap_top - 10 &&
      pix_y < gap_top;

  wire bottom_cap =
      pipe_cap_horizontal &&
      pix_y > gap_bottom &&
      pix_y <= gap_bottom + 10;

 
  // 7. Color and pixel draw
  always @(*) begin

    // Default: blue sky
    red = 0;
    green = 2;
    blue = 3;

    if (video_active) begin

      // Ground
      if (pix_y >= GROUND_Y) begin

        red = 0;
        green = 2;
        blue = 0;

      end

      // Pipes
      if (top_pipe || bottom_pipe) begin

        red = 0;
        green = 3;
        blue = 0;

      end

      // Pipe caps
      if (top_cap || bottom_cap) begin

        red = 0;
        green = 2;
        blue = 0;

      end

      // Bird body
      if (bird_body) begin

        red = 3;
        green = 3;
        blue = 0;

      end

      // Bird beak
      if (bird_beak) begin

        red = 3;
        green = 1;
        blue = 0;

      end


      // Game over panel
      if (game_over &&
          pix_x >= 190 && pix_x < 450 &&
          pix_y >= 190 && pix_y < 280) begin

        red = 3;
        green = 0;
        blue = 0;

        if (pix_x >= 200 && pix_x < 440 &&
            pix_y >= 200 && pix_y < 270) begin

          red = 0;
          green = 0;
          blue = 1;

        end

      end

    end

    else begin

      // Outside visible screen
      red = 0;
      green = 0;
      blue = 0;

    end

  end

  // Connect RGB colors to original VGA signals
  assign R = red;
  assign G = green;
  assign B = blue;

endmodule
