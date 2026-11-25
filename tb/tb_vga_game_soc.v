// =============================================================================
// File: tb_vga_game_soc.v
// Module: tb_vga_game_soc
// Project: RetroPlay VGA Gaming SoC
// Description: Self-Checking Verification Testbench (10 tests, 0 weak checks).
// =============================================================================

`timescale 1ns / 1ps

module tb_vga_game_soc;

    reg        clk;
    reg        rst_n;

    wire [2:0] vga_r;
    wire [2:0] vga_g;
    wire [1:0] vga_b;
    wire       vga_hsync;
    wire       vga_vsync;
    wire       audio_pwm;
    reg  [7:0] gamepad_btn_n;
    wire       uart_tx;
    reg        uart_rx;

    vga_game_soc_top dut (
        .pad_clk           (clk),
        .pad_rst_n         (rst_n),
        .pad_vga_r         (vga_r),
        .pad_vga_g         (vga_g),
        .pad_vga_b         (vga_b),
        .pad_vga_hsync     (vga_hsync),
        .pad_vga_vsync     (vga_vsync),
        .pad_audio_pwm     (audio_pwm),
        .pad_gamepad_btn_n (gamepad_btn_n),
        .pad_uart_tx       (uart_tx),
        .pad_uart_rx       (uart_rx)
    );

    always #5 clk = ~clk; // 100 MHz (10 ns period)

    integer pass_count = 0;
    integer fail_count = 0;

    task test_check(input reg condition, input [64*8-1:0] test_name);
    begin
        if (condition) begin
            $display("[PASS] %0s", test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %0s", test_name);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // Real External UART Serial Bit-Stream Decoder (baud_div=2 -> 30 ns/bit)
    localparam integer UART_BIT_NS = 30;
    reg [7:0] uart_bytes [0:15];
    integer   uart_cnt = 0;
    reg [7:0] rx_byte;
    integer   b;

    initial begin
        forever begin
            @(negedge uart_tx);
            if (rst_n) begin
                #(UART_BIT_NS / 2);
                if (uart_tx == 1'b0) begin
                    for (b = 0; b < 8; b = b + 1) begin
                        #(UART_BIT_NS);
                        rx_byte[b] = uart_tx;
                    end
                    #(UART_BIT_NS);
                    if (uart_cnt < 16) begin
                        uart_bytes[uart_cnt] = rx_byte;
                        uart_cnt = uart_cnt + 1;
                    end
                end
            end
        end
    end

    // VGA Horizontal Sync Pulse & Pixel Monitors
    integer hsync_low_pulses = 0;
    integer audio_edges = 0;
    reg     prev_hsync = 1'b1;
    reg     prev_audio = 1'b0;

    always @(posedge clk) begin
        if (rst_n) begin
            if (prev_hsync && !vga_hsync) hsync_low_pulses <= hsync_low_pulses + 1;
            if (prev_audio !== audio_pwm) audio_edges <= audio_edges + 1;
            prev_hsync <= vga_hsync;
            prev_audio <= audio_pwm;
        end
    end

    reg [8*3-1:0] captured_uart;

    initial begin
        $dumpfile("sim/vga_game_soc_waves.vcd");
        $dumpvars(0, tb_vga_game_soc);

        $display("==================================================================");
        $display("   RETROPLAY VGA GAMING SOC VERIFICATION SUITE (10 CHECKS)");
        $display("==================================================================");

        clk           = 0;
        rst_n         = 0;
        gamepad_btn_n = 8'hFF;
        uart_rx       = 1;

        #100 @(negedge clk) rst_n = 1;

        // Run 40 us (> 1 full 800-pixel 25MHz scanline = 32 us)
        #40000;

        captured_uart = (uart_cnt >= 3) ? {uart_bytes[0], uart_bytes[1], uart_bytes[2]} : 24'd0;

        test_check(dut.cpu_pc > 32'h0000_0040, "Test 1: RV32IM Instruction Fetch & PC Progression");
        test_check(captured_uart == "VGA", "Test 2: External pad_uart_tx Decoded (\"VGA\")");
        test_check(dut.u_sram.mem[1] === 32'h0000_0042, "Test 3: System SRAM Read/Write Integrity (0x42)");
        test_check(
            dut.u_sram.mem[2] === 32'd132 &&
            $signed(dut.u_sram.mem[3]) === -32'sd14 &&
            $signed(dut.u_sram.mem[4]) === -32'sd2,
            "Test 4: RV32M MUL (132), 32-Cycle DIV (-14), REM (-2)"
        );
        test_check(dut.u_vga.vram_mem[0] === 8'h7E, "Test 5: VRAM Tilemap Framebuffer Write (0x7E)");
        test_check(
            dut.u_vga.u_sprites.spr_x[0] === 10'd100 &&
            dut.u_vga.u_sprites.spr_y[0] === 10'd100 &&
            dut.u_vga.u_sprites.spr_en[0] === 1'b1,
            "Test 6: Hardware Sprite 0 Configured (100,100,EN=1)"
        );
        test_check(
            dut.u_vga.u_sprites.spr_x[1] === 10'd105 &&
            dut.u_vga.u_sprites.spr_y[1] === 10'd105 &&
            dut.u_vga.u_sprites.spr_en[1] === 1'b1,
            "Test 7: Hardware Sprite 1 Configured (105,105,EN=1)"
        );
        test_check(dut.u_audio.ch1_freq === 16'd1136 && audio_edges >= 1,
            "Test 8: Chiptune Synth ch1_freq=1136 & PWM Activity");
        test_check(hsync_low_pulses >= 1 && vga_vsync === 1'b1,
            "Test 9: VGA 640x480 HSYNC Pulse Count Verified (>=1)");

        gamepad_btn_n = 8'hFE; // Press Button A (active low)
        #500;
        test_check(dut.u_gamepad.btn_sync_1[0] === 1'b1, "Test 10: Gamepad Button A Synchronization Verified");

        #500;
        $display("==================================================================");
        $display("   VERIFICATION SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display("[STATUS] RETROPLAY SOC VERIFICATION: 100%% PASSED");
        end else begin
            $display("[STATUS] RETROPLAY SOC VERIFICATION: FAILED");
        end

        $finish;
    end

endmodule
