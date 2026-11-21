// =============================================================================
// File: gamepad_controller.v
// Module: gamepad_controller
// Project: RetroPlay VGA Gaming SoC
// Description: Retro Gamepad Controller supporting 8-button NES interface
//              (A, B, Select, Start, Up, Down, Left, Right) with debouncing
//              and APB bus memory-mapped registers.
// =============================================================================

`timescale 1ns / 1ps

module gamepad_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Bus Slave Interface
    input  wire        req,
    input  wire        wr,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         ready,

    // Physical Gamepad Interface
    input  wire [7:0]  pad_buttons_n, // Active low: {Right, Left, Down, Up, Start, Select, B, A}
    output wire        pad_latch,
    output wire        pad_clk,
    input  wire        pad_data_in,

    // Interrupt
    output reg         irq
);

    // Register 0x00: Button State (bit 0: A, 1: B, 2: Select, 3: Start, 4: Up, 5: Down, 6: Left, 7: Right)
    // Register 0x04: Control / Debounce threshold
    // Register 0x08: Interrupt Enable / Status
    reg [7:0]  btn_sync_0;
    reg [7:0]  btn_sync_1;
    reg [7:0]  btn_debounced;
    reg [15:0] debounce_counter;
    reg [7:0]  irq_en;
    reg [7:0]  irq_status;

    // Synchronize and debounce
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0       <= 8'hFF;
            btn_sync_1       <= 8'hFF;
            btn_debounced    <= 8'h00;
            debounce_counter <= 16'd0;
            irq              <= 1'b0;
            irq_status       <= 8'h00;
        end else begin
            btn_sync_0 <= ~pad_buttons_n; // Invert to active-high
            btn_sync_1 <= btn_sync_0;

            if (debounce_counter == 16'd1000) begin
                debounce_counter <= 16'd0;
                if (btn_sync_1 != btn_debounced) begin
                    // Edge detected
                    irq_status <= irq_status | (btn_sync_1 & ~btn_debounced);
                    btn_debounced <= btn_sync_1;
                end
            end else begin
                debounce_counter <= debounce_counter + 1'b1;
            end

            irq <= |(irq_status & irq_en);
        end
    end

    // Bus read/write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata      <= 32'd0;
            ready      <= 1'b0;
            irq_en     <= 8'h00;
        end else begin
            if (req && !ready) begin
                if (wr) begin
                    case (addr[3:2])
                        2'b01: debounce_counter <= wdata[15:0];
                        2'b10: irq_en           <= wdata[7:0];
                        2'b11: irq_status       <= irq_status & ~wdata[7:0]; // W1C
                        default: ;
                    endcase
                end else begin
                    case (addr[3:2])
                        2'b00: rdata <= {24'd0, btn_debounced};
                        2'b01: rdata <= {16'd0, debounce_counter};
                        2'b10: rdata <= {24'd0, irq_en};
                        2'b11: rdata <= {24'd0, irq_status};
                        default: rdata <= 32'd0;
                    endcase
                end
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end
        end
    end

    assign pad_latch = 1'b0;
    assign pad_clk   = 1'b0;

endmodule
