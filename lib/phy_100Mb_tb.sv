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
 *  Description: PHY 100Mb interface RGMII, RMII and MII test bench for signal
 *               visualization.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module phy_100Mb_tb;
/*============================================================================*/

reg clk = 0;
reg rx_clk = 0;

wire rx1_clk;
wire [7:0] rx1_d;
reg  [7:0] rx1_data = 0;
wire rx1_dv;
wire rx1_er;
wire tx1_clk;
reg  [7:0] tx1_d = 0;
reg  tx1_dv = 0;

wire phy1_rx_clk;
wire [3:0] phy1_rxd;
wire phy1_rgmii_rx_ctrl;
wire phy1_rgmii_tx_clk;
wire [3:0] phy1_txd;
wire phy1_rgmii_tx_ctrl;

assign phy1_rxd = phy1_txd;
assign phy1_rgmii_rx_ctrl = phy1_rgmii_tx_ctrl;

phy_100Mb #(
    .CFG_MODE( "RGMII" ))
phy1 (
    .clk(clk),
    .rx_clk(rx1_clk),
    .rx_d(rx1_d),
    .rx_dv(rx1_dv),
    .rx_er(rx1_er),
    .tx_clk(tx1_clk),
    .tx_d(tx1_d),
    .tx_dv(tx1_dv),
    .phy_rx_clk(phy1_rx_clk),
    .phy_rxd(phy1_rxd),
    .phy_rgmii_rx_ctrl(phy1_rgmii_rx_ctrl),
    .phy_mii_rx_dv(),
    .phy_mii_rx_er(),
    .phy_mii_tx_clk(phy1_rx_clk),
    .phy_rmii_clk(),
    .phy_rgmii_tx_clk(phy1_rgmii_tx_clk),
    .phy_txd(phy1_txd),
    .phy_mii_tx_en(),
    .phy_rgmii_tx_ctrl(phy1_rgmii_tx_ctrl)
    );

wire rx2_clk;
wire [7:0] rx2_d;
reg  [7:0] rx2_data = 0;
wire rx2_dv;
wire rx2_er;
wire tx2_clk;
reg  [7:0] tx2_d = 0;
reg  tx2_dv = 0;

wire phy2_rx_clk;
wire [3:0] phy2_rxd;
wire phy2_mii_rx_dv;
reg  phy2_mii_rx_er = 0;
wire phy2_mii_tx_clk;
wire phy2_mii_tx_en;
wire [3:0] phy2_txd;

assign phy2_rxd = phy2_txd;
assign phy2_mii_rx_dv = phy2_mii_tx_en;

phy_100Mb #(
    .CFG_MODE( "MII" ))
phy2 (
    .clk(clk),
    .rx_clk(rx2_clk),
    .rx_d(rx2_d),
    .rx_dv(rx2_dv),
    .rx_er(rx2_er),
    .tx_clk(tx2_clk),
    .tx_d(tx2_d),
    .tx_dv(tx2_dv),
    .phy_rx_clk(phy2_rx_clk),
    .phy_rxd(phy2_rxd),
    .phy_rgmii_rx_ctrl(),
    .phy_mii_rx_dv(phy2_mii_rx_dv),
    .phy_mii_rx_er(phy2_mii_rx_er),
    .phy_mii_tx_clk(phy2_mii_tx_clk),
    .phy_rmii_clk(),
    .phy_rgmii_tx_clk(),
    .phy_txd(phy2_txd),
    .phy_mii_tx_en(phy2_mii_tx_en),
    .phy_rgmii_tx_ctrl()
    );

wire rx3_clk;
wire [7:0] rx3_d;
reg  [7:0] rx3_data = 0;
wire rx3_dv;
wire rx3_er;
wire tx3_clk;
reg  [7:0] tx3_d = 0;
reg  tx3_dv = 0;

wire phy3_rmii_clk;
wire [3:0] phy3_rxd;
wire phy3_mii_rx_dv;
reg  phy3_mii_rx_er = 0;
wire phy3_mii_tx_en;
wire [3:0] phy3_txd;

assign phy3_rxd = phy3_txd;
assign phy3_mii_rx_dv = phy3_mii_tx_en;

phy_100Mb #(
    .CFG_MODE( "RMII" ))
phy3 (
    .clk(clk),
    .rx_clk(rx3_clk),
    .rx_d(rx3_d),
    .rx_dv(rx3_dv),
    .rx_er(rx3_er),
    .tx_clk(tx3_clk),
    .tx_d(tx3_d),
    .tx_dv(tx3_dv),
    .phy_rx_clk(),
    .phy_rxd(phy3_rxd),
    .phy_rgmii_rx_ctrl(),
    .phy_mii_rx_dv(phy3_mii_rx_dv),
    .phy_mii_rx_er(phy3_mii_rx_er),
    .phy_mii_tx_clk(),
    .phy_rmii_clk(phy3_rmii_clk),
    .phy_rgmii_tx_clk(),
    .phy_txd(phy3_txd),
    .phy_mii_tx_en(phy3_mii_tx_en),
    .phy_rgmii_tx_ctrl()
    );

always #5 clk = ~clk; // 100MHz clock
always #20 rx_clk = ~rx_clk; // 25MHz clock

assign phy1_rx_clk = rx_clk;
assign phy2_rx_clk = rx_clk;
assign phy2_mii_tx_clk = rx_clk;

reg [1:0] tx1_clk_i = 0;
reg [1:0] tx2_clk_i = 0;
reg [1:0] tx3_clk_i = 0;
/*============================================================================*/
always @(clk) begin : tx_clock
/*============================================================================*/
    tx1_clk_i <= {tx1_clk_i[0], tx1_clk};
    tx2_clk_i <= {tx2_clk_i[0], tx2_clk};
    tx3_clk_i <= {tx3_clk_i[0], tx3_clk};
end // tx_clock

/*============================================================================*/
always @(posedge rx1_clk) begin : rx1_data_collect
/*============================================================================*/
    if ( rx1_dv ) begin
        rx1_data <= rx1_d;
    end
end // rx1_data_collect

/*============================================================================*/
always @(posedge rx2_clk) begin : rx2_data_collect
/*============================================================================*/
    if ( rx2_dv ) begin
        rx2_data <= rx2_d;
    end
end // rx2_data_collect

/*============================================================================*/
always @(posedge rx3_clk) begin : rx3_data_collect
/*============================================================================*/
    if ( rx3_dv ) begin
        rx3_data <= rx3_d;
    end
end // rx3_data_collect

/*============================================================================*/
task phy_write( input integer phy,
                input [7:0] phy_d );
/*============================================================================*/
begin
    if ( 1 == phy ) begin
        wait ( 2'b10 == tx1_clk_i );
        tx1_d = phy_d;
        tx1_dv = 1;
        wait ( 2'b11 == tx1_clk_i );
    end
    if ( 2 == phy ) begin
        wait ( 2'b10 == tx2_clk_i );
        tx2_d = phy_d;
        tx2_dv = 1;
        wait ( 2'b11 == tx2_clk_i );
    end
    if ( 3 == phy ) begin
        wait ( 2'b10 == tx3_clk_i );
        tx3_d = phy_d;
        tx3_dv = 1;
        wait ( 2'b11 == tx3_clk_i );
    end
end
endtask // mdio_rw

/*============================================================================*/
initial begin
/*============================================================================*/
    #100
    $display( "PHY interface simulation started" );
    phy_write( 1, 8'h81 );
    phy_write( 1, 8'h5A );
    phy_write( 1, 8'hA5 );
    phy_write( 1, 8'h81 );
    phy_write( 1, 0 );
    wait ( 2'b10 == tx1_clk_i );
    tx1_dv = 0;
    phy_write( 2, 8'h81 );
    phy_write( 2, 8'h5A );
    phy_write( 2, 8'hA5 );
    phy_write( 2, 8'h81 );
    phy_write( 2, 0 );
    wait ( 2'b10 == tx2_clk_i );
    tx2_dv = 0;
    phy_write( 3, 8'h81 );
    phy_write( 3, 8'h5A );
    phy_write( 3, 8'hA5 );
    phy_write( 3, 8'h81 );
    phy_write( 3, 0 );
    wait ( 2'b10 == tx3_clk_i );
    tx3_dv = 0;
    #200
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "phy_100Mb_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // phy_100Mb_tb
