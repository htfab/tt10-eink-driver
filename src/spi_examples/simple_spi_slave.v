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

//-----------------------------------------------------------
// simple_spi_slave.v
//-----------------------------------------------------------
// General purpose SPI module.  This module handles the
// SPI protocol and nothing else.  It assumes a format
// of one command word (8 bits) followed by one address
// (8 bits) followed by some number of data bytes (8 bits).
// The command words are described below.  The SPI master
// is responsible for understanding the format and sending
// the correct number of data bytes.  This module has a
// general-purpose interface to a processor to exchange
// byte-wise information, with the module providing the
// address and data sent by the master, and sending read
// and write strobe signals to the processor to tell it
// when to capture the data or send new data.
//-----------------------------------------------------------
// Written by Tim Edwards
// efabless, inc., September 28, 2020
//------------------------------------------------
// This file is distributed free and open source
//------------------------------------------------

// SCK ---   Clock input
// SDI ---   Data  input
// SDO ---   Data  output
// CSB ---   Chip  select (sense negative)
// idata --- Data from chip to transmit out, in 8 bits
// odata --- Input data to chip, in 8 bits
// addr  --- Decoded address to upstream circuits
// rdstb --- Read strobe, tells upstream circuit that data will be latched.
// wrstb --- Write strobe, tells upstream circuit to latch odata.

// Data format (general purpose):
// 8 bit format
// 1st byte:   Command word (see below)
// 2nd byte:   Address word (register 0 to 255)
// 3rd byte:   Data word    (value 0 to 255)

// Command format:
// 00000000  No operation
// 10000000  Write until CSB raised
// 01000000  Read  until CSB raised
// 11000000  Simultaneous read/write until CSB raised
// wrnnn000  Read/write as above, for nnn = 1 to 7 bytes, then terminate

// All serial bytes are read and written msb first.

// This generic slave has 8 fixed general-purpos read/write registers,
// Address 0 to 7.

`define COMMAND  3'b000
`define ADDRESS  3'b001
`define DATA     3'b010

module simple_spi_slave(reset, SCK, SDI, CSB, SDO,
	sdoenb, idata, odata, oaddr, rdstb, wrstb)

    input reset;		// Reset (sense positive)
    input SCK;			// SPI clock
    input SDI;			// SPI data in (MOSI)
    input CSB;			// SPI select (sense negative)
    output SDO;			// SPI data out (MISO)
    output sdoenb;		// Output enable on SDO

    input [7:0] idata;		// Input data from processor
    output [7:0] odata;		// Output data to processor
    output [7:0] oaddr;		// Output address
    output rdstb;		// Read strobe (ready for new data)
    output wrstb; 		// Write strobe (data valid)

    reg  [7:0]  addr;
    reg		wrstb;
    reg		rdstb;
    reg		sdoenb;
    reg  [2:0]  state;
    reg  [2:0]  count;
    reg		writemode;
    reg		readmode;
    reg  [2:0]	fixed;
    wire [7:0]  odata;
    reg  [6:0]  predata;
    wire [7:0]  oaddr;
    reg  [7:0]  ldata;
    wire	csb_reset;

    assign odata = {predata, SDI};
    assign oaddr = (state == `ADDRESS) ? {addr[6:0], SDI} : addr;
    assign SDO = ldata[7];
    assign csb_reset = CSB | reset;

    // Readback data is captured on the falling edge of SCK so that
    // it is guaranteed valid at the next rising edge.

    always @(negedge SCK or posedge csb_reset) begin
        if (csb_reset == 1'b1) begin
            wrstb <= 1'b0;
            ldata  <= 8'b00000000;
            sdoenb <= 1'b1;
        end else begin

            // After CSB low, 1st SCK starts command

            if (state == `DATA) begin
            	if (readmode == 1'b1) begin
                    sdoenb <= 1'b0;
                    if (count == 3'b000) begin
                	ldata <= idata;
                    end else begin
                	ldata <= {ldata[6:0], 1'b0};	// Shift out
                    end
                end else begin
                    sdoenb <= 1'b1;
                end

                // Apply write strobe on SCK negative edge on the next-to-last
                // data bit so that it updates data on the rising edge of SCK
                // on the last data bit.
 
                if (count == 3'b111) begin
                    if (writemode == 1'b1) begin
                        wrstb <= 1'b1;
                    end
                end else begin
                    wrstb <= 1'b0;
                end

            end else begin
                wrstb <= 1'b0;
                sdoenb <= 1'b1;
            end		// ! state `DATA
        end		// ! csb_reset
    end			// always @ ~SCK

    always @(posedge SCK or posedge csb_reset) begin
        if (csb_reset == 1'b1) begin
            // Default state on reset
            addr <= 8'h00;
	    rdstb <= 1'b0;
            predata <= 7'b0000000;
            state  <= `COMMAND;
            count  <= 3'b000;
            readmode <= 1'b0;
            writemode <= 1'b0;
            fixed <= 3'b000;
        end else begin
            // After csb_reset low, 1st SCK starts command
            if (state == `COMMAND) begin
		rdstb <= 1'b0;
                count <= count + 1;
        	if (count == 3'b000) begin
	            writemode <= SDI;
	        end else if (count == 3'b001) begin
	            readmode <= SDI;
	        end else if (count < 3'b101) begin
	            fixed <= {fixed[1:0], SDI}; 
	        end else if (count == 3'b111) begin
	            state <= `ADDRESS;
	        end
            end else if (state == `ADDRESS) begin
	        count <= count + 1;
	        addr <= {addr[6:0], SDI};
	        if (count == 3'b111) begin
	            state <= `DATA;
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
		    rdstb <= 1'b0;
		end

            end else if (state == `DATA) begin
	        predata <= {predata[6:0], SDI};
	        count <= count + 1;
	        if (count == 3'b111) begin
	            if (fixed == 3'b001) begin
	                state <= `COMMAND;
	            end else if (fixed != 3'b000) begin
	                fixed <= fixed - 1;
	                addr <= addr + 1;	// Auto increment address (fixed)
	            end else begin	
	                addr <= addr + 1;	// Auto increment address (streaming)
	            end
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
		    rdstb <= 1'b0;
		end
            end		// ! state `DATA
        end		// ! csb_reset 
    end			// always @ SCK

endmodule // simple_spi_slave
`default_nettype wire
