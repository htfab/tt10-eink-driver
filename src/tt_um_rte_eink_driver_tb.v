//-------------------------------------
// Testbench for tt_um_rte_eink_driver
//-------------------------------------

`default_nettype none

`timescale 1 ns / 1 ps

`include "tt_um_rte_eink_driver.v"

module tt_um_rte_eink_driver_tb;

    reg ena;
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    wire	pwm;

    initial begin
	$dumpfile("tt_um_rte_eink_driver_tb.vcd");
	$dumpvars(0, tt_um_rte_eink_driver_tb);

	ena <= 0;
	clk <= 0;
	rst_n <= 0;
	ui_in <= 0;

	// Enable the project (this signal is unused by the project)
	#100;
	ena <= 1;

	// Bring project out of reset
	#500;
	rst_n <= 1;

	// 2 million count = 1 wave at 500Hz
	// Run for a while in silence
	#4000000;

	// Apply a note
	ui_in <= 1;
	#4000000;

	// Apply another note, overlapping
	ui_in <= 5;
	#10000;
	ui_in <= 4;
	#4000000;

	// Applky another note, non-overlapping
	ui_in <= 0;
	#2000000;

	ui_in <= 6;
	#2000000;

	$finish;
    end

    // 10ns half cycle = 20ns cycle = 50MHz clock
    always #10 clk <= (clk === 1'b0);

    tt_um_rte_eink_driver dut (
	.ui_in(ui_in),
	.uo_out(uo_out),
	.uio_in(8'h00),		// Keep at zero (unused)
	.uio_out(uio_out),
	.uio_oe(uio_oe),
	.ena(ena),
	.clk(clk),
	.rst_n(rst_n)
    );

    assign pwm = uio_out[7];	// For easier viewing in gtkwave

    // To do: instantiate e-ink display as two SPI slave modules,
    // one for the display and one for the SRAM.

endmodule;
