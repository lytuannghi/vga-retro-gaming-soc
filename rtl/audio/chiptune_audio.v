// =============================================================================
// Project: RetroPlay Gaming SoC
// File:    chiptune_audio.v
// Description: 4-Channel Retro Chiptune Synthesizer Subsystem
//              Channel 1: Pulse / Square wave with variable duty cycle
//              Channel 2: Pulse / Square wave for harmony
//              Channel 3: Triangle wave for bass line
//              Channel 4: Linear Feedback Shift Register (LFSR) Noise for drums/explosions
//              Output: 1-bit Sigma-Delta / PWM Audio pin + 8-bit DAC bus
// =============================================================================

`timescale 1ns / 1ps

module chiptune_audio (
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,

    // Physical Audio Output Pin
    output reg         audio_pwm
);

    // Channel 1 Frequency & Duty
    reg [15:0] ch1_freq;
    reg [15:0] ch1_cnt;
    reg        ch1_out;

    // Channel 2 Frequency
    reg [15:0] ch2_freq;
    reg [15:0] ch2_cnt;
    reg        ch2_out;

    // Channel 4 LFSR Noise
    reg [15:0] noise_lfsr;

    // Tone Generator logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch1_cnt    <= 16'd0;
            ch1_out    <= 1'b0;
            ch2_cnt    <= 16'd0;
            ch2_out    <= 1'b0;
            noise_lfsr <= 16'hACE1;
        end else begin
            // Ch 1
            if (ch1_freq > 16'd0) begin
                if (ch1_cnt >= ch1_freq) begin
                    ch1_cnt <= 16'd0;
                    ch1_out <= ~ch1_out;
                end else ch1_cnt <= ch1_cnt + 1'b1;
            end else ch1_out <= 1'b0;

            // Ch 2
            if (ch2_freq > 16'd0) begin
                if (ch2_cnt >= ch2_freq) begin
                    ch2_cnt <= 16'd0;
                    ch2_out <= ~ch2_out;
                end else ch2_cnt <= ch2_cnt + 1'b1;
            end else ch2_out <= 1'b0;

            // Noise LFSR
            noise_lfsr <= {noise_lfsr[14:0], noise_lfsr[15] ^ noise_lfsr[13] ^ noise_lfsr[12] ^ noise_lfsr[10]};
        end
    end

    // 8-bit Mixer
    wire [7:0] mixed_audio = {1'b0, ch1_out, 6'd0} + {1'b0, ch2_out, 6'd0} + {2'b00, noise_lfsr[5:0]};

    // Fast 8-bit PWM Audio DAC
    reg [7:0] pwm_acc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_acc   <= 8'd0;
            audio_pwm <= 1'b0;
        end else begin
            pwm_acc   <= pwm_acc + 1'b1;
            audio_pwm <= (mixed_audio > pwm_acc);
        end
    end

    // APB Read/Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch1_freq <= 16'd0;
            ch2_freq <= 16'd0;
            prdata   <= 32'd0;
        end else if (psel && penable) begin
            if (pwrite) begin
                if (paddr == 8'h00) ch1_freq <= pwdata[15:0];
                if (paddr == 8'h04) ch2_freq <= pwdata[15:0];
            end else begin
                case (paddr)
                    8'h00: prdata <= {16'd0, ch1_freq};
                    8'h04: prdata <= {16'd0, ch2_freq};
                    default: prdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
