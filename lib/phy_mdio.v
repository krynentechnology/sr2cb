/**
 *  Copyright (C) 2025, Kees Krijnen.
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
 *  Description: PHY MDIO protocol (ST = STart, OP = OPcode, PA = Phy Address,
 *               RA = Register Address, TA = Turn Around, D16 = data,
 *               Z = tristate, RD = ReaD, WR = WRite)
 *
 *          ST  OP  PA5   RA5   TA  D16
 *  RD:     0 1 1 0 bbbbb bbbbb Z 0 bbbb...bbbb
 *  WR:     0 1 0 1 bbbbb bbbbb 1 0 bbbb...bbbb
 *
 *  Supports parallel PHYs (each PHY has a separate MDC and MDIO line). Always
 *  one idle bit when no preamble is required. Data is sampled after falling
 *  edge for reading. Data is set before rising edge for writing. PHY MDC clock
 *  has a maximum rate specified!
 *
 *  https://en.wikipedia.org/wiki/Management_Data_Input/Output
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module phy_mdio #(
/*============================================================================*/
    parameter [4:0] NR_PHY = 2,
    parameter [5:0] PREAMBLE = 1, // 1 to 32-bit preamble, minumum 1 idle bit
    parameter [0:0] TL_BIDIR = 0, // 1 = top level bidirectional pin only
    parameter [0:0] PARALLEL = 0 ) // 1 = each PHY has a separate
    (                              // MDC and MDIO line
    clk, // Clock rate > 4 * mdio_clk clock rate!
    rst_n, // Synchronous reset, high when clk is stable!
    mdio_clk,
    s_mdio_pa, // PHY address, select MDC and MDIO lines when PARALLEL=1
    s_mdio_ra, // Register address
    s_mdio_d, // Data in
    s_mdio_dv, // Data valid
    s_mdio_rd, // Read = 1, Write = 0
    s_mdio_dr, // Data ready
    m_mdio_pa, // PHY address id when PARALLEL=1
    m_mdio_d, // Data out
    m_mdio_dv, // Data valid
    mdc, // Management Data Clock
    mdio, // Management Data Input Output
    mdio_i, // MDIO in
    mdio_o, // MDIO out
    mdio_oe // MDIO out enable
    );

localparam MAX_CLOG2_WIDTH = 5;
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

localparam PA_WIDTH = clog2( NR_PHY );

input  wire clk;
input  wire rst_n;
input  wire mdio_clk;
input  wire [PA_WIDTH-1:0] s_mdio_pa;
input  wire [4:0] s_mdio_ra;
input  wire [15:0] s_mdio_d;
input  wire s_mdio_dv;
output wire s_mdio_dr;
input  wire s_mdio_rd;
input  wire [4:0] m_mdio_pa;
output reg  [15:0] m_mdio_d = 0;
output reg  m_mdio_dv = 0;
output wire [NR_PHY-1:0] mdc;
inout  wire [NR_PHY-1:0] mdio;
input  wire mdio_i;
output reg  mdio_o = 0;
output reg  mdio_oe = 0;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if (( PREAMBLE < 1 ) || ( PREAMBLE > 32 )) begin
        $display( "( PREAMBLE < 1 ) || ( PREAMBLE > 32 )!" );
        $finish;
    end
end // parameter_check

reg  [1:0] mdio_clk_i = 0;
reg  [PA_WIDTH-1:0] s_mdio_pa_i = 0;
reg  [15:0] s_mdio_a_i = 0;
reg  [15:0] s_mdio_d_i = 0;
reg  s_mdio_dr_n = 0;
reg  s_mdio_rd_i = 0;
reg  [15:0] m_mdio_d_i = 0;
reg  [5:0] bit_count = 0;
wire mdio_ii;
wire mdio_iii;

assign s_mdio_dr = ~s_mdio_dr_n;

genvar i;
generate
if ( PARALLEL ) begin
    for ( i = 0; i < NR_PHY; i = i + 1 ) begin : parallel_mdio
    assign mdc[i] = ( s_mdio_dr_n && ( i == s_mdio_pa_i )) ? mdio_clk : 1'b0;
    assign mdio[i] = ( s_mdio_dr_n && mdio_oe && ( i == s_mdio_pa_i )) ? mdio_o : 1'bZ;
    end
    assign mdio_ii = mdio[s_mdio_pa_i];
end else begin
    assign mdc[0] = s_mdio_dr_n ? mdio_clk : 1'b0;
    assign mdio[0] = ( s_mdio_dr_n && mdio_oe ) ? mdio_o : 1'bZ;
    assign mdio_ii = mdio[0];
end // PARALLEL
endgenerate

assign mdio_iii = TL_BIDIR ? mdio_i : mdio_ii;

/*============================================================================*/
always @(posedge clk) begin : mdio_protocol
/*============================================================================*/
    mdio_clk_i <= {mdio_clk_i[0], mdio_clk};
    m_mdio_dv <= 0;
    if ( 2'b10 == mdio_clk_i ) begin // Falling edge MDC
        if ( s_mdio_dv && !s_mdio_dr_n ) begin
            s_mdio_dr_n <= 1;
            s_mdio_a_i[15:14] <= 2'b01; // Start sequence
            s_mdio_a_i[13] <= s_mdio_rd; // Opcode
            s_mdio_a_i[12] <= ~s_mdio_rd;
            s_mdio_a_i[11:7] <= PARALLEL ? m_mdio_pa : s_mdio_pa;
            s_mdio_a_i[6:2] <= s_mdio_ra;
            s_mdio_a_i[1:0] <= 2'b10; // Turn Around
            s_mdio_pa_i <= s_mdio_pa[PA_WIDTH-1:0];
            s_mdio_d_i <= s_mdio_d;
            s_mdio_rd_i <= s_mdio_rd;
            mdio_o <= 1;
            mdio_oe <= 1;
            bit_count <= 6'd31 + PREAMBLE;
        end
        if ( s_mdio_dr_n ) begin
            bit_count <= bit_count - 1;
            if ( 2'b01 == bit_count[5:4] || ( 6'd32 == bit_count ) ) begin
                mdio_o <= s_mdio_a_i[15];
                s_mdio_a_i <= {s_mdio_a_i[14:0], 1'b0};
                m_mdio_d_i <= 0;
                if ( s_mdio_rd_i && ( 4'h2 == bit_count[3:0] )) begin
                    mdio_oe <= 0; // Disable MDIO output
                end
            end
            if (( 2'b00 == bit_count[5:4] ) || ( 6'd16 == bit_count )) begin
                mdio_o <= s_mdio_d_i[15];
                s_mdio_d_i <= {s_mdio_d_i[14:0], 1'b0};
            end
            if ( 0 == bit_count ) begin
                s_mdio_dr_n <= 0;
                mdio_o <= 0;
                mdio_oe <= 0;
            end
            if ( s_mdio_rd_i && ( 0 == bit_count[5:4] )) begin
                m_mdio_d_i <= {m_mdio_d_i[14:0], mdio_iii};
            end
        end
    end
    if ( !s_mdio_dr_n && &bit_count ) begin // bit_count = 6'h3F
        m_mdio_d <= m_mdio_d_i;
        m_mdio_dv <= s_mdio_rd_i;
        bit_count <= 0;
    end
    if ( !rst_n ) begin
        bit_count <= 0;
        s_mdio_dr_n <= 0;
        s_mdio_rd_i <= 0;
        s_mdio_a_i <= 0;
        mdio_o <= 0;
        mdio_oe <= 0;
        m_mdio_d <= 0;
        m_mdio_dv <= 0;
    end
end // mdio_protocol

endmodule // phy_mdio
