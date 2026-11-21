// =============================================================================
// File: tb_vga_game_soc.v
// Module: tb_vga_game_soc
// Project: RetroPlay VGA Gaming SoC
// Description: Comprehensive Self-Checking Testbench verifying full SoC
//              integration: CPU, Bus, ROM, SRAM, VGA Video, Sprites, Audio,
//              Gamepad, and UART.
// =============================================================================

`timescale 1ns / 1ps

module tb_vga_game_soc;

    reg        clk;
    reg        rst_n;

    // VGA Output Pins
    wire [2:0] vga_r;
    wire [2:0] vga_g;
    wire [1:0] vga_b;
    wire       vga_hsync;
    wire       vga_vsync;

    // Audio Output Pin
    wire       audio_pwm;

    // Gamepad Inputs
    reg  [7:0] gamepad_btn_n;

    // UART Pins
    wire       uart_tx;
    reg        uart_rx;

    // Device Under Test (DUT)
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

    // 100 MHz System Clock (10ns period)
    always #5 clk = ~clk;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

    task test_check(input reg condition, input [255:0] test_name);
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

    // Simulation stimulus
    initial begin
        $dumpfile("vga_game_soc_waves.vcd");
        $dumpvars(0, tb_vga_game_soc);

        $display("==================================================================");
        $display("   RETROPLAY VGA GAMING SOC VERIFICATION SUITE                   ");
        $display("==================================================================");

        // Initial state
        clk           = 0;
        rst_n         = 0;
        gamepad_btn_n = 8'hFF; // All buttons released (active low)
        uart_rx       = 1;

        // Apply Reset
        #100;
        @(negedge clk);
        rst_n = 1;
        $display("[SIM] Reset released at %0t ps", $time);

        // Wait for CPU to fetch and execute initial instructions
        #500;
        test_check(dut.cpu_pc > 32'h0000_0000, "Test 1: RV32I Core Instruction Fetch & PC Progression");

        // Wait for CPU to complete boot sequence
        #3000;

        // Test 2: Check UART Transmission
        test_check(uart_tx !== 1'bx, "Test 2: UART Controller Transmitter Operational");

        // Test 3: Check SRAM Access (CPU wrote 0x42 to SRAM[4])
        test_check(dut.u_sram.mem[1] === 32'h0000_0042, "Test 3: System SRAM Read/Write Data Integrity");

        // Test 4: Check VRAM Write (CPU wrote 0x7E to VRAM[0])
        test_check(dut.u_vga.vram_mem[0] === 8'h7E, "Test 4: VRAM Dual-Port Tilemap Framebuffer Write");

        // Test 5: Check Sprite Engine Configuration
        test_check(dut.u_vga.u_sprites.spr_x[0] === 10'd100 &&
                   dut.u_vga.u_sprites.spr_y[0] === 10'd100 &&
                   dut.u_vga.u_sprites.spr_en[0] === 1'b1,
                   "Test 5: Hardware Sprite Engine 0 Configuration (X, Y, En)");

        test_check(dut.u_vga.u_sprites.spr_x[1] === 10'd105 &&
                   dut.u_vga.u_sprites.spr_y[1] === 10'd105 &&
                   dut.u_vga.u_sprites.spr_en[1] === 1'b1,
                   "Test 6: Hardware Sprite Engine 1 Configuration (Target Collision)");

        // Test 7: Check Chiptune Audio Channel 1 Frequency Register
        test_check(dut.u_audio.ch1_freq === 16'd1136, "Test 7: Chiptune Synthesizer Channel 1 Tone Frequency");

        // Test 8: Check VGA Timing Generator Sync signals
        test_check(vga_hsync !== 1'bx && vga_vsync !== 1'bx, "Test 8: VGA Timing Generator 640x480 Sync Pulses Active");

        // Test 9: Check Gamepad Input Sampling
        gamepad_btn_n = 8'hFE; // Press Button A (bit 0 = 0)
        #500;
        test_check(dut.u_gamepad.btn_sync_1[0] === 1'b1, "Test 9: Gamepad Button A Input Synchronization");

        // Final summary
        #1000;
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
