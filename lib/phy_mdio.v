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
                 RA = Register Address, TA = Turn Around, D16 = data,
                 Z = tristate, RD = ReaD, WR = WRite)
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
    parameter [0:0] PREAMBLE = 0, // 1 = 32-bit preamble
    parameter [0:0] PARALLEL = 0 ) // 1 = each PHY has a separate
    (                              // MDC and MDIO line
    clk, // Clock rate > 4 * mdio_clk clock rate!
    rst_n, // Synchronous reset, high when clk is stable!
    mdio_clk,
    m_mdio_pa, // PHY address, select MDC and MDIO lines when PARALLEL=1
    m_mdio_ra, // Register address
    m_mdio_d, // Data in
    m_mdio_dv, // Data valid
    m_mdio_rw, // Read = 1, Write = 0
    m_mdio_dr, // Data ready
    s_mdio_pa, // PHY address id when PARALLEL=1
    s_mdio_d, // Data out
    s_mdio_dv, // Data valid
    mdc, // Management Data Clock
    mdio // Management Data Input Output
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
input  wire [PA_WIDTH-1:0] m_mdio_pa;
input  wire [4:0] m_mdio_ra;
input  wire [15:0] m_mdio_d;
input  wire m_mdio_dv;
output wire  m_mdio_dr;
input  wire m_mdio_rw;
input  wire [4:0] s_mdio_pa;
output reg  [15:0] s_mdio_d = 0;
output reg  s_mdio_dv = 0;
output wire [NR_PHY-1:0] mdc;
inout  wire [NR_PHY-1:0] mdio;

reg  [1:0] mdio_clk_i = 0;
reg  [PA_WIDTH-1:0] m_mdio_pa_i = 0;
reg  [15:0] m_mdio_a_i = 16'h4002;
reg  [15:0] m_mdio_d_i = 0;
reg  m_mdio_dr_i = 1;
reg  m_mdio_rw_i = 0;
reg  [15:0] s_mdio_d_i = 0;
reg  mdio_i = 1'bZ;
reg  [5:0] bit_count = 6'h3F;
reg  mdio_busy = 0;
reg  preamble = 0;

wire bit_count_zero;
assign bit_count_zero = ( 0 == bit_count );
assign m_mdio_dr = m_mdio_dr_i & ~m_mdio_dv;

genvar i;
generate
if ( PARALLEL ) begin
    for ( i = 0; i < NR_PHY; i = i + 1 ) begin
    assign mdc[i] = ( !m_mdio_dr_i && ( i == m_mdio_pa_i )) ? mdio_clk : 1'b0;
    assign mdio[i] = ( !m_mdio_dr_i && ( i == m_mdio_pa_i )) ? mdio_i : 1'bZ;
    end
end else begin
    assign mdc[0] = !m_mdio_dr_i ? mdio_clk : 1'b0;
    assign mdio[0] = !m_mdio_dr_i ? mdio_i : 1'bZ;
end
endgenerate

/*============================================================================*/
always @(posedge clk) begin : mdio_protocol
/*============================================================================*/
    mdio_clk_i <= {mdio_clk_i[0], mdio_clk};
    if ( 2'b10 == mdio_clk_i ) begin
        if ( m_mdio_dv && m_mdio_dr_i ) begin
            m_mdio_a_i[15:14] <= 2'b01; // Start sequence
            m_mdio_a_i[13] <= ~m_mdio_rw; // Opcode
            m_mdio_a_i[12] <= m_mdio_rw;
            m_mdio_a_i[11:7] <= PARALLEL ? s_mdio_pa : m_mdio_pa;
            m_mdio_a_i[6:2] <= m_mdio_ra;
            m_mdio_a_i[1:0] <= 2'b10; // Turn Around
            m_mdio_pa_i <= m_mdio_pa;
            m_mdio_d_i <= m_mdio_d;
            m_mdio_rw_i <= m_mdio_rw;
            m_mdio_dr_i <= 0;
            bit_count <= 6'h3F;
            if ( PREAMBLE ) begin
                bit_count[1] <= 0; // Count minus two due to one idle bit
                preamble <= 1;
                mdio_i <= 1'b1;
            end
        end
        if ( bit_count_zero ) begin
            if ( !mdio_busy ) begin
                m_mdio_dr_i <= 1;
                s_mdio_d <= s_mdio_d_i;
                s_mdio_dv <= ~m_mdio_rw_i;
            end
        end
    end
    if ( 2'b01 == mdio_clk_i ) begin
        if ( !m_mdio_dr_i ) begin // One idle bit
            mdio_busy <= 1;
        end
    end
    if (( 2'b10 == mdio_clk_i ) || ( 2'b01 == mdio_clk_i )) begin
        if ( mdio_busy ) begin
            if ( bit_count_zero && !( PREAMBLE && preamble )) begin
                mdio_busy <= 0;
            end else begin
                bit_count <= bit_count - 1;
                if ( bit_count_zero && ( PREAMBLE && preamble )) begin
                    preamble <= 0; // Conditional synthesis!
                end
            end
            mdio_i <= 1'b0;
            if ( PREAMBLE && preamble ) begin
                mdio_i <= 1'b1; // Conditional synthesis!
            end else if ( bit_count[5] ) begin
                if ( bit_count[0] ) begin
                    mdio_i <= m_mdio_a_i[15];
                    m_mdio_a_i <= {m_mdio_a_i[14:0], 1'b0};
                end
                if (( bit_count < 6'd36 ) && !m_mdio_rw_i ) begin
                    mdio_i <= 1'bZ;
                    s_mdio_dv <= 0;
                    s_mdio_d_i <= 0;
                end
            end else if ( m_mdio_rw_i ) begin
                if ( bit_count[0] ) begin
                    mdio_i <= m_mdio_d_i[15];
                    m_mdio_d_i <= {m_mdio_d_i[14:0], 1'b0};
                end
            end else begin
                mdio_i <= 1'bZ;
                if ( bit_count[0] ) begin
                    s_mdio_d_i <= {s_mdio_d_i[14:0], mdio[m_mdio_pa_i]};
                end
            end
        end
    end
    if ( !rst_n ) begin
        bit_count <= 6'h3F;
        m_mdio_dr_i <= 1;
        m_mdio_rw_i <= 0;
        m_mdio_a_i = 16'h4002;
        mdio_i <= 1'bZ;
        mdio_busy <= 0;
        preamble <= 0;
        s_mdio_d <= 0;
        s_mdio_dv <= 0;
    end
end // mdio_protocol

endmodule // phy_mdio
