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
 *  Description: PHY 100Mb interface RGMII, MII and RMII
 *
 *  https://en.wikipedia.org/wiki/Media-independent_interface
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module phy_100Mb #(
/*============================================================================*/
    parameter CFG_MODE = "RMII" ) // Or "MII", "RGMII"
    (
    input  wire clk, // Should be 100MHz for RMII!
    output wire rx_clk, // RX clock
    output reg  [7:0] rx_d = 0, // Byte read data
    output reg  rx_dv = 0, // Read data valid
    output reg  rx_er = 0, // Read error
    output wire tx_clk, // TX clock
    input  wire [7:0] tx_d, // Byte write data
    input  wire tx_dv,// Write data valid,
    // PHY interface
    input  wire phy_rx_clk,
    input  wire [3:0] phy_rxd,
    input  wire phy_rgmii_rx_ctrl,
    input  wire phy_mii_rx_dv,
    input  wire phy_mii_rx_er,
    input  wire phy_mii_tx_clk,
    output wire phy_rmii_clk, // RMII 50MHz reference clock!
    output wire phy_rgmii_tx_clk,
    output reg  [3:0] phy_txd = 0,
    output reg  phy_mii_tx_en = 0,
    output reg  phy_rgmii_tx_ctrl = 0
    );

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( CFG_MODE != "RGMII" && CFG_MODE != "MII" && CFG_MODE != "RMII" ) begin
        $display( "Select one of the PHY 100Mb interface modes!" );
        $finish;
    end
end // parameter_check

generate
if ( "RGMII" == CFG_MODE ) begin

reg rx_clk_i = 0;
assign rx_clk = rx_clk_i;
reg [1:0] rx_clk_ii = 0;

/*============================================================================*/
always @(posedge phy_rx_clk) begin : rx_clock_out
/*============================================================================*/
    rx_clk_i <= ~rx_clk_i;
end

reg [3:0] rx_d_i = 0;
reg rx_dv_i = 0;
reg [3:0] tx_d_i = 0;
reg tx_dv_i = 0;
reg tx_dv_ii = 0;

assign tx_clk = rx_clk_i;
assign phy_rgmii_tx_clk = phy_rx_clk;

/*============================================================================*/
always @(negedge phy_rx_clk) begin : rgmii_mii_rx // RGMII in MII mode
/*============================================================================*/
    rx_er <= ~phy_rgmii_rx_ctrl;
    rx_dv_i <= 0;
    if ( phy_rgmii_rx_ctrl ) begin
        if ( !rx_dv_i ) begin
            rx_dv_i <= 1;
            rx_d_i <= phy_rxd; // Copy low nibble
        end
        if ( rx_dv_i ) begin
            rx_dv <= 1;
            rx_d[3:0] <= rx_d_i;
            rx_d[7:4] <= phy_rxd;
        end
    end else begin
        rx_dv <= 0;
    end
end // rgmii_mii_rx

/*============================================================================*/
always @(posedge phy_rx_clk) begin : rgmii_mii_tx // RGMII in MII mode
/*============================================================================*/
    tx_dv_i <= 0;
    tx_dv_ii <= 0;
    phy_txd <= 4'hF; // Carrier extend
    phy_rgmii_tx_ctrl <= 0;
    if ( tx_dv && !tx_dv_i ) begin
        tx_dv_i <= 1;
        phy_txd <= tx_d[3:0]; // Low nibble
        tx_d_i <= tx_d[7:4]; // Copy high nibble
        phy_rgmii_tx_ctrl <= 1;
    end
    if ( tx_dv_i && !tx_dv_ii ) begin
        tx_dv_ii <= 1;
        phy_txd <= tx_d_i; // Hign nibble
        phy_rgmii_tx_ctrl <= 1;
    end
    if ( tx_dv_ii ) begin // End of frame nibble
        phy_rgmii_tx_ctrl <= 1;
    end
end // rgmii_mii_tx

end else if ( "MII" == CFG_MODE ) begin

reg rx_clk_i = 0;
assign rx_clk = rx_clk_i;

/*============================================================================*/
always @(posedge phy_rx_clk) begin : rx_clock_out
/*============================================================================*/
    rx_clk_i <= ~rx_clk_i;
end

reg [3:0] rx_d_i = 0;
reg rx_dv_i = 0;
/*============================================================================*/
always @(negedge phy_rx_clk) begin : mii_rx
/*============================================================================*/
    rx_er <= phy_mii_rx_er;
    rx_dv_i <= 0;
    if ( phy_mii_rx_dv ) begin
        if ( !rx_dv_i ) begin
            rx_dv_i <= 1;
            rx_d_i <= phy_rxd; // Copy low nibble
        end
        if ( rx_dv_i ) begin
            rx_dv <= 1;
            rx_d[3:0] <= rx_d_i;
            rx_d[7:4] <= phy_rxd;
        end
    end else begin
        rx_dv <= 0;
    end
end // mii_rx

reg tx_clk_i = 0;
assign tx_clk = tx_clk_i;
reg [3:0] tx_d_i = 0;
reg tx_dv_i = 0;
reg tx_dv_ii = 0;

/*============================================================================*/
always @(posedge phy_mii_tx_clk) begin : mii_tx // Plus TX clock out
/*============================================================================*/
    tx_clk_i <= ~tx_clk_i;
    tx_dv_i <= 0;
    tx_dv_ii <= 0;
    phy_txd <= 4'hF; // Carrier extend
    phy_mii_tx_en <= 0;
    if ( tx_dv && !tx_dv_i ) begin
        tx_dv_i <= 1;
        phy_txd <= tx_d[3:0]; // Low nibble
        tx_d_i <= tx_d[7:4]; // Copy high nibble
        phy_mii_tx_en <= 1;
    end
    if ( tx_dv_i && !tx_dv_ii ) begin
        tx_dv_ii <= 1;
        phy_txd <= tx_d_i; // Hign nibble
        phy_mii_tx_en <= 1;
    end
    if ( tx_dv_ii ) begin // End of frame nibble
        phy_mii_tx_en <= 1;
    end
end // mii_tx

end else begin // if ( "RMII" == CFG_MODE )

reg rmii_clk = 0;
assign phy_rmii_clk = rmii_clk;

/*============================================================================*/
always @(posedge clk) begin : rmii_clk_50Mhz
/*============================================================================*/
    rmii_clk <= ~rmii_clk; // 50Mhz
end // rmii_clk_50Mhz

reg rmii_clk_i = 0;
reg rmii_clk_ii = 0;
assign rx_clk = rmii_clk_ii;
assign tx_clk = rmii_clk_ii;

reg [5:0] rx_d_i = 0;
reg rx_dv_i = 0;
reg rx_dv_ii = 0;
reg rx_dv_iii = 0;

/*============================================================================*/
always @(posedge rmii_clk) begin : rmii_rx
/*============================================================================*/
    rmii_clk_i <= ~rmii_clk_i; // 25Mhz
    if ( !( phy_mii_rx_dv || rx_dv_i || rx_dv_ii || rx_dv_iii )) begin
        rx_dv <= 0;
    end
    rx_dv_i <= 0;
    if ( phy_mii_rx_dv && !rx_dv_i ) begin
        rx_dv_i <= 1;
        rx_d_i[1:0] <= phy_rxd[1:0];
    end
    rx_dv_ii <= 0;
    if ( rx_dv_i && !rx_dv_ii ) begin
        rx_dv_i <= 1;
        rx_dv_ii <= 1;
        rx_d_i[3:2] <= phy_rxd[1:0];
    end
    rx_dv_iii <= 0;
    if ( rx_dv_ii && !rx_dv_iii ) begin
        rx_dv_i <= 1;
        rx_dv_ii <= 1;
        rx_dv_iii <= 1;
        rx_d_i[5:4] <= phy_rxd[1:0];
    end
    if ( rx_dv_iii ) begin
        rx_dv <= phy_mii_rx_dv;
        rx_d[5:0] <= rx_d_i;
        rx_d[7:6] <= phy_rxd[1:0];
    end
end // mii_rx

reg [5:0] tx_d_i = 0;
reg tx_dv_i = 0;
reg tx_dv_ii = 0;
reg tx_dv_iii = 0;

/*============================================================================*/
always @(posedge rmii_clk) begin : rmii_tx
/*============================================================================*/
    tx_dv_i <= 0;
    if ( !rmii_clk_i ) begin
        if ( tx_dv && !tx_dv_i ) begin
            phy_txd[1:0] <= tx_d[1:0];
            tx_d_i <= tx_d[7:2]; // Copy upper 6-bit TX data
            if ( !tx_clk ) begin
                tx_dv_i <= 1;
            end
        end
        phy_mii_tx_en <= tx_dv;
    end
    tx_dv_ii <= 0;
    if ( tx_dv_i && !tx_dv_ii ) begin
        tx_dv_i <= 1;
        tx_dv_ii <= 1;
        phy_txd[1:0] <= tx_d_i[1:0];
    end
    tx_dv_iii <= 0;
    if ( tx_dv_ii && !tx_dv_iii ) begin
        tx_dv_i <= 1;
        tx_dv_ii <= 1;
        tx_dv_iii <= 1;
        phy_txd[1:0] <= tx_d_i[3:2];
    end
    if ( tx_dv_iii ) begin
        phy_txd[1:0] <= tx_d_i[5:4];
    end
end // rmii_tx

/*============================================================================*/
always @(posedge rmii_clk_i) begin : rx_tx_clk
/*============================================================================*/
    rmii_clk_ii <= ~rmii_clk_ii; // 12.5Mhz
end

end // if ( "RMII" == CFG_MODE )
endgenerate

endmodule // phy_100Mb
