`default_nettype none
/*
 *  SPDX-FileCopyrightText: 2015 Clifford Wolf
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  SPDX-License-Identifier: ISC
 */

/* The original module has been modified/simplified to remove the
 * wishbone interface, and to reduce the divider and configuration
 * bit widths to the minimum necessary.  For example, the FPGA board
 * rate of 100MHz with a 16-bit divider yields 1526 baud, which is
 * presumably sufficiently low for most purposes.  Also:  The
 * configuration and divider registers have been replaced with
 * a simple divider value input and an "enable" input.  Other
 * signals have been renamed for simplicity.
 *
 * Operation:  
 *	1) Apply the divder value while the UART is disabled.
 *	2) Raise "enable" to enable the UART
 *	3) To write a byte:
 *		a) Set "data_out" to the value to transmit
 *		b) Pulse the "write" signal
 *		c) Wait until "busy" returns to zero to send next byte
 *	4) To read a byte:
 *		a) Check "valid" for valid data at input
 *		b) Pulse the "read" signal
 *		c) Read the value from "data_in"
 *		d) If no input has been read, "data_in" reads 0xff.
 */

module simpleuart (
    input clk,			// Core clock
    input resetn,		// Reset (sense negative)

    output ser_tx,		// UART transmit (data out)
    input  ser_rx,		// UART receive  (data in)

    input  [15:0] divider,	// Core clock divider
    input  	  enable,	// UART enable
    input         write,	// Write data trigger
    input         read,		// Read data trigger
    input   [7:0] data_in,	// Input byte
    output  [7:0] data_out,	// Output byte
    output        busy,		// UART busy
    output	  valid		// Input received
);
    reg [3:0] recv_state;
    reg [15:0] recv_divcnt;
    reg [7:0] recv_pattern;
    reg [7:0] recv_buf_data;
    reg recv_buf_valid;

    reg [9:0] send_pattern;
    reg [3:0] send_bitcnt;
    reg [15:0] send_divcnt;
    reg send_dummy;

    assign busy = write || send_bitcnt || send_dummy;
    assign data_out = recv_buf_valid ? recv_buf_data : ~0;
    assign valid = recv_buf_valid;

    always @(posedge clk) begin
        if (!resetn) begin
            recv_state <= 0;
            recv_divcnt <= 0;
            recv_pattern <= 0;
            recv_buf_data <= 0;
            recv_buf_valid <= 0;
        end else begin
            recv_divcnt <= recv_divcnt + 1;
            if (read)
                recv_buf_valid <= 0;
            case (recv_state)
                0: begin
                    if (!ser_rx && enable)
                        recv_state <= 1;
                    recv_divcnt <= 0;
                end
                1: begin
                    if (2*recv_divcnt > divider) begin
                        recv_state <= 2;
                        recv_divcnt <= 0;
                    end
                end
                10: begin
                    if (recv_divcnt > divider) begin
                        recv_buf_data <= recv_pattern;
                        recv_buf_valid <= 1;
                        recv_state <= 0;
                    end
                end
                default: begin
                    if (recv_divcnt > divider) begin
                        recv_pattern <= {ser_rx, recv_pattern[7:1]};
                        recv_state <= recv_state + 1;
                        recv_divcnt <= 0;
                    end
                end
            endcase
        end
    end

    assign ser_tx = send_pattern[0];

    always @(posedge clk) begin
        if (!resetn) begin
            send_pattern <= ~0;
            send_bitcnt <= 0;
            send_divcnt <= 0;
            send_dummy <= 1;
        end else begin
            if (send_dummy && !send_bitcnt) begin
                send_pattern <= ~0;
                send_bitcnt <= 15;
                send_divcnt <= 0;
                send_dummy <= 0;
            end else if (write && !send_bitcnt) begin
                send_pattern <= {1'b1, data_in[7:0], 1'b0};
                send_bitcnt <= 10;
                send_divcnt <= 0;
            end else if (send_divcnt > divider && send_bitcnt) begin
                send_pattern <= {1'b1, send_pattern[9:1]};
                send_bitcnt <= send_bitcnt - 1;
                send_divcnt <= 0;
            end else begin
		send_divcnt <= send_divcnt + 1;
	    end
        end
    end
endmodule
`default_nettype wire
