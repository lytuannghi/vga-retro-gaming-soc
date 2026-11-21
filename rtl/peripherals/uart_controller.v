// =============================================================================
// File: uart_controller.v
// Module: uart_controller
// Project: RetroPlay VGA Gaming SoC
// Description: Full-duplex UART controller with configurable baud rate divisor
//              and APB-compatible bus slave interface.
// =============================================================================

`timescale 1ns / 1ps

module uart_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Bus Slave Interface
    input  wire        req,
    input  wire        wr,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         ready,

    // Serial Pins
    output reg         uart_tx,
    input  wire        uart_rx,
    output reg         tx_irq
);

    // Registers:
    // 0x00: TX Data (W) / RX Data (R)
    // 0x04: Status (bit 0: TX busy, bit 1: RX ready)
    // 0x08: Baud Divisor (default: 868 for 115200 baud at 100MHz)
    reg [15:0] baud_div;
    reg [15:0] baud_cnt;
    reg [9:0]  tx_shift;
    reg [3:0]  tx_bit_cnt;
    reg        tx_busy;

    reg [7:0]  rx_buf;
    reg        rx_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata      <= 32'd0;
            ready      <= 1'b0;
            baud_div   <= 16'd868; // 100MHz / 115200 = 868
            baud_cnt   <= 16'd0;
            tx_shift   <= 10'h3FF;
            tx_bit_cnt <= 4'd0;
            tx_busy    <= 1'b0;
            uart_tx    <= 1'b1;
            tx_irq     <= 1'b0;
            rx_buf     <= 8'd0;
            rx_ready   <= 1'b0;
        end else begin
            // Bus interface
            if (req && !ready) begin
                if (wr) begin
                    case (addr[3:2])
                        2'b00: begin // TX Data
                            if (!tx_busy) begin
                                tx_shift   <= {1'b1, wdata[7:0], 1'b0}; // Stop bit, 8 data bits, Start bit
                                tx_bit_cnt <= 4'd10;
                                tx_busy    <= 1'b1;
                            end
                        end
                        2'b10: baud_div <= wdata[15:0];
                        default: ;
                    endcase
                end else begin
                    case (addr[3:2])
                        2'b00: begin
                            rdata    <= {24'd0, rx_buf};
                            rx_ready <= 1'b0;
                        end
                        2'b01: rdata <= {30'd0, rx_ready, tx_busy};
                        2'b10: rdata <= {16'd0, baud_div};
                        default: rdata <= 32'd0;
                    endcase
                end
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end

            // UART TX Engine
            if (tx_busy) begin
                if (baud_cnt >= baud_div) begin
                    baud_cnt <= 16'd0;
                    uart_tx  <= tx_shift[0];
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    if (tx_bit_cnt == 4'd1) begin
                        tx_busy <= 1'b0;
                        tx_irq  <= 1'b1;
                    end else begin
                        tx_bit_cnt <= tx_bit_cnt - 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end else begin
                baud_cnt <= 16'd0;
                uart_tx  <= 1'b1;
                tx_irq   <= 1'b0;
            end
        end
    end

endmodule
