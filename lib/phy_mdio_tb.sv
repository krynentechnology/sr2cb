/**
 *  Copyright (C) 2025, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: PHY MDIO test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module phy_mdio_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;
reg mdio_clk = 0;
reg [1:0] mdc = 0;

reg [4:0] s_mdio_pa = 0;
reg [4:0] s_mdio_ra = 0;
reg [15:0] s_mdio_d = 0;
reg s_mdio_dv = 0;
reg s_mdio_rd = 0;

wire s_mdio_dr_1;
wire [15:0] m_mdio_d_1;
wire m_mdio_dv_1;
reg  [15:0] s_mdio_1 = 0;
reg  [15:0] m_mdio_1 = 0;
reg  mdio_rd_1 = 0;
reg  [1:0] mdio_rd_status_1 = 0;
reg  mdio_wr_1 = 0;
wire mdc_1;
wire mdio_1;

phy_mdio #(
    .NR_PHY( 1 ),
    .PREAMBLE( 0 ),
    .PARALLEL( 0 ))
phy1 (
    .clk(clk),
    .rst_n(rst_n),
    .mdio_clk(mdio_clk),
    .s_mdio_pa(s_mdio_pa[0]),
    .s_mdio_ra(s_mdio_ra),
    .s_mdio_d(s_mdio_d),
    .s_mdio_dv(s_mdio_dv),
    .s_mdio_dr(s_mdio_dr_1),
    .s_mdio_rd(s_mdio_rd),
    .m_mdio_pa(),
    .m_mdio_d(m_mdio_d_1),
    .m_mdio_dv(m_mdio_dv_1),
    .mdc(mdc_1),
    .mdio(mdio_1)
    );

wire s_mdio_dr_2;
wire [15:0] m_mdio_d_2;
wire m_mdio_dv_2;
reg  [15:0] s_mdio_2 = 0;
reg  [15:0] m_mdio_2 = 0;
reg  mdio_rd_2 = 0;
reg  [1:0] mdio_rd_status_2 = 0;
reg  mdio_wr_2 = 0;
wire mdc_2;
wire mdio_2;

phy_mdio #(
    .NR_PHY( 1 ),
    .PREAMBLE( 0 ),
    .PARALLEL( 1 ))
phy2 (
    .clk(clk),
    .rst_n(rst_n),
    .mdio_clk(mdio_clk),
    .s_mdio_pa(s_mdio_pa[0]),
    .s_mdio_ra(s_mdio_ra),
    .s_mdio_d(s_mdio_d),
    .s_mdio_dv(s_mdio_dv),
    .s_mdio_dr(s_mdio_dr_2),
    .s_mdio_rd(s_mdio_rd),
    .m_mdio_pa(5'd1),
    .m_mdio_d(m_mdio_d_2),
    .m_mdio_dv(m_mdio_dv_2),
    .mdc(mdc_2),
    .mdio(mdio_2)
    );

wire s_mdio_dr_3;
wire [15:0] m_mdio_d_3;
wire m_mdio_dv_3;
reg  [15:0] s_mdio_3 = 0;
reg  [15:0] m_mdio_3 = 0;
reg  mdio_rd_3 = 0;
reg  [1:0] mdio_rd_status_3 = 0;
reg  mdio_wr_3 = 0;
wire [2:0] mdc_3;
wire [2:0] mdio_3;

phy_mdio #(
    .NR_PHY( 3 ),
    .PREAMBLE( 1 ),
    .PARALLEL( 1 ))
phy3 (
    .clk(clk),
    .rst_n(rst_n),
    .mdio_clk(mdio_clk),
    .s_mdio_pa(2'd2),
    .s_mdio_ra(5'd4),
    .s_mdio_d(s_mdio_d),
    .s_mdio_dv(s_mdio_dv),
    .s_mdio_dr(s_mdio_dr_3),
    .s_mdio_rd(s_mdio_rd),
    .m_mdio_pa(5'd31),
    .m_mdio_d(m_mdio_d_3),
    .m_mdio_dv(m_mdio_dv_3),
    .mdc(mdc_3),
    .mdio(mdio_3)
    );

/*============================================================================*/
always @(posedge clk) begin : read_write_data
/*============================================================================*/
    mdc <= {mdc[0], mdio_clk};
    if ( 2'b01 == mdc ) begin // Rising edge MDC
        if ( s_mdio_dr_3 ) begin
            s_mdio_1 <= 0;
            mdio_rd_1 <= 0;
            mdio_rd_status_1 <= 0;
            mdio_wr_1 <= 0;
            s_mdio_2 <= 0;
            mdio_rd_2 <= 0;
            mdio_rd_status_2 <= 0;
            mdio_wr_2 <= 0;
            s_mdio_3 <= 0;
            mdio_rd_3 <= 0;
            mdio_rd_status_3 <= 0;
            mdio_wr_3 <= 0;
        end else begin
            s_mdio_1 <= {s_mdio_1[14:0], mdio_1};
            if ( 4'b0110 == s_mdio_1[3:0] && !mdio_wr_1 ) begin
                mdio_rd_1 <= 1;
            end
            if ( mdio_rd_1 && ( 1'bZ === mdio_1 )) begin // Detect MDIO = Z
                mdio_rd_status_1 <= 1;
            end
            if (( 1 == mdio_rd_status_1 ) && ( 0 == mdio_1 )) begin // Detect Z0
                mdio_rd_status_1 <= 2;
            end
            if ( 2 == mdio_rd_status_1 ) begin
                m_mdio_1 <= {m_mdio_1[14:0], 1'b0};
            end
            if ( 4'b0101 == s_mdio_1[3:0] && !mdio_rd_1 ) begin
                mdio_wr_1 <= 1;
            end
            if ( mdio_wr_1 && !s_mdio_dr_1 ) begin
                m_mdio_1 <= {m_mdio_1[14:0], mdio_1};
            end
            /*---------------------------------*/
            s_mdio_2 <= {s_mdio_2[14:0], mdio_2};
            if ( 4'b0110 == s_mdio_2[3:0] && !mdio_wr_2 ) begin
                mdio_rd_2 <= 1;
            end
            if ( mdio_rd_2 && ( 1'bZ === mdio_2 )) begin // Detect MDIO = Z
                mdio_rd_status_2 <= 1;
            end
            if (( 1 == mdio_rd_status_2 ) && ( 0 == mdio_2 )) begin // Detect Z0
                mdio_rd_status_2 <= 2;
            end
            if ( 2 == mdio_rd_status_2 ) begin
                m_mdio_2 <= {m_mdio_2[14:0], 1'b0};
            end
            if ( 4'b0101 == s_mdio_2[3:0] && !mdio_rd_2 ) begin
                mdio_wr_2 <= 1;
            end
            if ( mdio_wr_2  && !s_mdio_dr_2 ) begin
                m_mdio_2 <= {m_mdio_2[14:0], mdio_2};
            end
            /*---------------------------------*/
            s_mdio_3 <= {s_mdio_3[14:0], mdio_3[2]}; // PA = 2!
            if ( 4'b0110 == s_mdio_3[3:0] && !mdio_wr_3 ) begin
                mdio_rd_3 <= 1;
            end
            if ( mdio_rd_3 && ( 1'bZ === mdio_3[2] )) begin // Detect MDIO = Z
                mdio_rd_status_3 <= 1;
            end
            if (( 1 == mdio_rd_status_3 ) && ( 0 == mdio_3[2] )) begin // Detect Z0
                mdio_rd_status_3 <= 2;
            end
            if ( 2 == mdio_rd_status_3 ) begin
                m_mdio_3 <= {m_mdio_3[14:0], 1'b0};
            end
            if ( 4'b0101 == s_mdio_3[3:0] && !mdio_rd_3 ) begin
                mdio_wr_3 <= 1;
            end
            if ( mdio_wr_3 ) begin
                m_mdio_3 <= {m_mdio_3[14:0], mdio_3[2]};
            end
        end
    end
end // read_write_data

assign mdio_1 = ( 1 == mdio_rd_status_1 ) ? 0 : ( mdio_rd_status_1 > 1 ) ? m_mdio_1[15] : 1'bZ;
assign mdio_2 = ( 1 == mdio_rd_status_2 ) ? 0 : ( mdio_rd_status_2 > 1 ) ? m_mdio_2[15] : 1'bZ;
assign mdio_3[2] = ( 1 == mdio_rd_status_3 ) ? 0 : ( mdio_rd_status_3 > 1 ) ? m_mdio_3[15] : 1'bZ;

/*============================================================================*/
task mdio_rw( input [4:0] pa,
              input [4:0] ra,
              input [15:0] m_d,
              input [0:0] rw );
/*============================================================================*/
begin
    s_mdio_pa = pa;
    s_mdio_ra = ra;
    if ( rw ) begin
        s_mdio_d = m_d;
    end
    s_mdio_rd = rw;
    wait ( s_mdio_dr_3 && !mdio_clk );
    s_mdio_dv = 1;
    wait ( mdio_clk ) @( posedge mdio_clk );
    s_mdio_dv = 0;
    if ( rw ) begin
        wait ( m_mdio_dv_3 );
    end else begin
        wait ( s_mdio_dr_3 );
    end
end
endtask // mdio_rw

always #5 clk = ~clk; // 100MHz clock
always #50 mdio_clk = ~mdio_clk; // 10MHz clock

reg passed = 0;
/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    m_mdio_1 = 0;
    m_mdio_2 = 0;
    m_mdio_3 = 0;
    #100
    $display( "PHY MDIO simulation started" );
    rst_n = 1;
    mdio_rw( 0, 0, 16'h8003, 0 );
    passed = (( s_mdio_d == m_mdio_1 ) && ( s_mdio_d == m_mdio_2 ) && ( s_mdio_d == m_mdio_3 ));
    $display( "MDIO write %s", passed ? "passed" : "failed" );
    #100
    m_mdio_1 = 16'h8003;
    m_mdio_2 = 16'hC003;
    m_mdio_3 = 16'hC813;
    mdio_rw( 0, 21, 0, 1 );
    passed = (( m_mdio_d_1 == 16'h8003 ) && ( m_mdio_d_2 == 16'hC003 ) && ( m_mdio_d_3 == 16'hC813 ));
    $display( "MDIO read %s", passed ? "passed" : "failed" );
    #500 // 5us
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "phy_mdio_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // phy_mdio_tb
