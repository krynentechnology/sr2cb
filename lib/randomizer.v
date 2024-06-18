/**
 *  Copyright (C) 2024, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU Lesser General Public License as published by the
 *  Free Software Foundation, either version 3 of the License, or (at your
 *  option) any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program. If not, see <https://www.gnu.org/licenses/> for a
 *  copy.
 *
 *  License: LGPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/lgpl-3.0.html
 *
 *  Description: Pseudo randomizer
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module randomizer #(
/*============================================================================*/
    parameter OUTPUT_WIDTH = 32,
    // Tap points to insert XNOR gates as feedback, (2^OUTPUT_WIDTH)-1 numbers are
    // cycled through before the sequence is repeated (see Xilinx XAPP052)
    parameter [OUTPUT_WIDTH-1:0] LFSR_TAP = 'b1000_0000_00100_0000_0000_0000_000_0011 )
    (
    input  wire clk,
    input  wire rst_n,
    output wire [OUTPUT_WIDTH-1:0] random_out
    );

localparam MAX_CLOG2_WIDTH = 8;
/*============================================================================*/
function integer clog2( input [MAX_CLOG2_WIDTH-1:0] value );
/*============================================================================*/
    reg [MAX_CLOG2_WIDTH-1:0] depth;
    begin
        clog2 = 1; // Minimum bit width
        if ( value > 1 ) begin
            depth = value - 1;
            clog2 = 0;
            while ( depth > 0 ) begin
                depth = depth >> 1;
                clog2 = clog2 + 1;
            end
        end
    end
endfunction // clog2

localparam COUNTER_WIDTH = clog2( OUTPUT_WIDTH );

reg [OUTPUT_WIDTH-1:0] lfsr;

/*============================================================================*/
initial begin // Parameter checks
/*============================================================================*/
    if ( COUNTER_WIDTH > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "COUNTER_WIDTH > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
    if ( !LFSR_TAP[OUTPUT_WIDTH-1] ) begin
        $display( "Invalid LFSR_TAP = %b" , LFSR_TAP );
        $finish;
    end
    if ( OUTPUT_WIDTH < 3 ) begin
        $display( "Invalid OUTPUT_WIDTH = %d", OUTPUT_WIDTH );
        $finish;
    end
    lfsr = 0;
end

/*============================================================================*/
always @(posedge clk) begin : galois_lfsr
/*============================================================================*/
    reg [COUNTER_WIDTH-1:0] i;

    lfsr[OUTPUT_WIDTH-1] <= lfsr[0];
    for ( i = 0; i < OUTPUT_WIDTH - 1; i = i + 1 ) begin
        lfsr[i] <= lfsr[i+1];
        if ( LFSR_TAP[i] ) begin
            lfsr[i] <= lfsr[i+1] ~^ lfsr[0];
        end
    end        
    if ( &lfsr || !rst_n ) begin
        lfsr <= 0;
    end    
end // galois_lfsr

assign random_out = lfsr;

endmodule
