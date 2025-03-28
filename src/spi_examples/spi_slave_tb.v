// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

/*
 *------------------------------------------------------	
 * Testbench driver for simple_spi_slave module
 *------------------------------------------------------	
 */

`timescale 1 ns / 1 ps

module spi_slave_tb;

    reg clock;
    reg SDI, CSB, SCK, RSTB;
    wire SDO;

    always #10 clock <= (clock === 1'b0);

    initial begin
	clock = 0;
    end

    /*
     * The main testbench is here.  Put the housekeeping SPI into
     * pass-thru mode and read several bytes from the flash SPI.
     */

    /* First define tasks for SPI functions */

    task start_csb;
    begin
	SCK <= 1'b0;
	SDI <= 1'b0;
	CSB <= 1'b0;
	#50;
    end
    endtask

    task end_csb;
    begin
	SCK <= 1'b0;
	SDI <= 1'b0;
	CSB <= 1'b1;
	#50;
    end
    endtask

    task write_byte;
    input [7:0] odata;
    begin
	SCK <= 1'b0;
	for (i=7; i >= 0; i--) begin
	    #50;
	    SDI <= odata[i];
	    #50;
	    SCK <= 1'b1;
	    #100;
	    SCK <= 1'b0;
	end
    end
    endtask

    task read_byte;
    output [7:0] idata;
    begin
	SCK <= 1'b0;
	SDI <= 1'b0;
	for (i=7; i >= 0; i--) begin
	    #50;
	    idata[i] = SDO;
	    #50;
	    SCK <= 1'b1;
	    #100;
	    SCK <= 1'b0;
	end
    end
    endtask

    task read_write_byte (
	input [7:0] odata,
	output [7:0] idata
    );
    begin
	SCK <= 1'b0;
	for (i=7; i >= 0; i--) begin
	    #50;
	    SDI <= odata[i];
	    idata[i] = SDO;
	    #50;
	    SCK <= 1'b1;
	    #100;
	    SCK <= 1'b0;
	end
    end
    endtask
	
    integer i;

    /* Now drive the digital signals on the SPI slave*/
    reg [7:0] tbdata;

    initial begin
	$dumpfile("spi_slave_tb.vcd");
	$dumpvars(0, spi_slave_tb);

	CSB <= 1'b1;
	SCK <= 1'b0;
	SDI <= 1'b0;
	RSTB <= 1'b0;

	/* Delay, then bring chip out of reset */

	#1000;
	RSTB <= 1'b1;
	#2000;

        /* First do a normal read from the SPI slave to
	 * make sure it's alive (no pass/fail check)
	 */

	start_csb();
	write_byte(8'h40);	// Read stream command
	write_byte(8'h00);	// Address (register 0)
	read_byte(tbdata);
	end_csb();
	#10;
	$display("Register 0 data = 0x%02x", tbdata);

	/* Write values to the first 10 registers
	 * (no pass/fail checks)
	 * Exercises single-address write, N-address write,
	 * and stream write modes.
	 */

	/* Send value 0xf0 to register 0, single-address write */
	start_csb();
	write_byte(8'h88);	// Write 1 value command
	write_byte(8'h00);	// Address (register 0)
	write_byte(8'hf0);	// Data = 0xf0
	end_csb();

	/* Send value 0xaa 0x55 0x12 to registers 1 through 3
	 * using a 3-address write
	 */
	start_csb();
	write_byte(8'h00);	// No-op command, should be ignored
	write_byte(8'h98);	// Write 3 values command
	write_byte(8'h01);	// Address (register 1)
	write_byte(8'haa);	// Data = 0xaa (to register 1)
	write_byte(8'h55);	// Data = 0x55 (to register 2)
	write_byte(8'h12);	// Data = 0x12 (to register 3)
	/* Do not raise CSB---SPI slave should be expecting next command */

	/* Send values 0x0f 0x67 0x25 0x38 to registers 4 through 7 using a
	 * stream write
	 */
	write_byte(8'h80);	// Write stream command
	write_byte(8'h04);	// Address (register 4)
	write_byte(8'h0f);	// Data = 0x0f (to register 4)
	write_byte(8'h67);	// Data = 0x67 (to register 5)
	write_byte(8'h25);	// Data = 0x25 (to register 6)
	write_byte(8'h38);	// Data = 0x38 (to register 7)
	end_csb();

	/* Send value 0x77 to register 9 using a stream write */
	start_csb();
	write_byte(8'h80);	// Write stream command
	write_byte(8'h09);	// Address (register 9)
	write_byte(8'h77);	// Data = 0x77 (to register 9)
	end_csb();

	/* Send value 0x11 to register 8 using a 1-byte write.
	 * Two values are sent;  the second one should be ignored
	 * so that register 9 retains the value written above.
	 */
	start_csb();
	write_byte(8'h88);	// Write one value command
	write_byte(8'h08);	// Address (register 8)
	write_byte(8'h11);	// Data = 0x11 (to register 8)
	write_byte(8'h88);	// This is another write one value command
	end_csb();		// Command is terminated by raising CSB

	/* Read all registers (0 to 9) */
	/* After the write sequence above, the registers should have values */
	/* 0xf0 0xaa 0x55 0x12 0x0f 0x67 0x25 0x38 0x11 0x77 */

	start_csb();
	write_byte(8'h40);	// Read stream command
	write_byte(8'h00);	// Address (register 0)
	read_byte(tbdata);

	$display("Read register 0 = 0x%02x (should be 0xf0)", tbdata);
	if (tbdata !== 8'hf0) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 1 = 0x%02x (should be 0xaa)", tbdata);
	if (tbdata !== 8'haa) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 2 = 0x%02x (should be 0x55)", tbdata);
	if (tbdata !== 8'h55) begin
	    $display("Monitor: Test SPI slave failed, %02x", tbdata); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 3 = 0x%02x (should be 0x12)", tbdata);
	if (tbdata !== 8'h12) begin 
	    $display("Monitor: Test SPI slave failed, %02x", tbdata); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 4 = 0x%02x (should be 0x0f)", tbdata);
	if (tbdata !== 8'h0f) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 5 = 0x%02x (should be 0x67)", tbdata);
	if (tbdata !== 8'h67) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 6 = 0x%02x (should be 0x25)", tbdata);
	if (tbdata !== 8'h25) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 7 = 0x%02x (should be 0x38)", tbdata);
	if (tbdata !== 8'h38) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 8 = 0x%02x (should be 0x11)", tbdata);
	if (tbdata !== 8'h11) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
	$display("Read register 9 = 0x%02x (should be 0x77)", tbdata);
	if (tbdata !== 8'h77) begin 
	    $display("Monitor: Test SPI slave failed"); $finish; 
	end
	read_byte(tbdata);
        end_csb();

	$display("Monitor: Test SPI slave passed");

	#10000;
 	$finish;
    end

endmodule
`default_nettype wire
