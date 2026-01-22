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
 *  Description: SR2CB protocol HW setup for Lattice Semiconductor ECP5 Versa
 *               Development Board
 *
 *  The ECP5 Versa Development Board has two 1Gbs PHYs. One is connected to the
 *  SR2CB master RX0/TX0 ring interface and the other to SR2CB slave 0 RX0/TX0
 *  ring interface. The ECP5 board PHYs are forced to 100Mbs, full duplex by
 *  terminal commands. The link is forced good to have a continuous PHYs RXCLK.
 *  The SR2CB master/slave modules require a continuously running RX0 and RX1
 *  clock. The PHYs are externally connected with a cross-wired RJ-45 cable.
 *  Terminal commands:
 *
 *    ECP5>00A100 // Write PHY1 reg 0 (0x00) to force 100Mb full duplex
 *    ECP5>20A100 // Write PHY2 reg 0 (0x20) to force 100Mb full duplex
 *    ECP5>100400 // Write PHY1 reg 16 (0x10) to force link good
 *    ECP5>300400 // Write PHY2 reg 16 (0x30) to force link good
 *    ECP5>11     // Read PHY1 reg 17 (0x11)
 *    ECP5>6C08   // 100Mbps, full duplex, auto-negotiation resolved and
 *                // (copper) link-up
 *    ECP5>31     // Read PHY2 reg 17 (0x31)
 *    ECP5>6C08   // 100Mbps, full duplex, auto-negotiation resolved and
 *                // (copper) link-up
 *    ECP5>803    // Force ring R0/R1 link up
 *
 *  For new HW designs the SR2CB master/slave RX0/RX1 rings could be setup with
 *  RMII PHYs (e.g. LAN8742A) where the 50MHz RX/TX PHY clock is provided by the
 *  FPGA and the LED link status could be an FPGA input.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "../lib/phy_100Mb.v"
// `include "../lib/phy_mdio.v"
// `include "../lib/randomizer.v"
// `include "../lib/uart.v"
// `include "../lib/uart_io.v"
// `include "../rtl/sr2cb_m_phy_pre.v"
// `include "../rtl/sr2cb_m.v"
// `include "../rtl/sr2cb_s.v"
`include "../rtl/sr2cb_def.v"

/*============================================================================*/
module ecp5_sr2cb (
/*============================================================================*/
    input  wire CLK, // 100Mhz LVDS clock
    input  wire ARST_N,
    // Marvell PHY 88E1512 RGMII interface
    output wire PHY1_RST_N,
    output wire PHY1_MDC,
    inout  wire PHY1_MDIO,
    input  wire PHY1_RGMII_RXCLK,
    input  wire [3:0] PHY1_RGMII_RXD,
    input  wire PHY1_RGMII_RXCTL,
    output wire PHY1_RGMII_TXCLK,
    output wire [3:0] PHY1_RGMII_TXD,
    output wire PHY1_RGMII_TXCTL,
    output wire PHY1_CONFIG, // PHYAD[0] hardware strapping
    output wire PHY2_RST_N,
    output wire PHY2_MDC,
    inout  wire PHY2_MDIO,
    input  wire PHY2_RGMII_RXCLK,
    input  wire PHY2_RGMII_RXCTL,
    input  wire [3:0] PHY2_RGMII_RXD,
    output wire PHY2_RGMII_TXCLK,
    output wire PHY2_RGMII_TXCTL,
    output wire [3:0] PHY2_RGMII_TXD,
    output wire PHY2_CONFIG, // PHYAD[0] hardware strapping
    //
    input  wire UART_RX,
    output wire UART_TX,
    output wire [7:0] LED,
    output wire DP, // Decimal point, negative logic 0=on, 1=off
    output wire [13:0] SEG, // 14 Segment display segments
    input  wire [7:0] DIP_SW
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
endfunction

localparam NR_CHANNELS = 4;
localparam NR_SR2CB_SLAVE_NODES = 3;
localparam CHW = clog2( NR_CHANNELS );
localparam NR_BITS = 8;

wire clk;
wire rst_n;
assign clk = CLK;

wire [7:0] uart_rx_d;
wire uart_rx_dv;
wire [7:0] uart_tx_d;
wire uart_tx_dv;
wire uart_tx_dr;

uart #(
    .CLK_FREQ( 100E6 ), // 100MHz
    .BAUD_RATE( 115.2E3 ), // 115K2
    .NR_BITS( NR_BITS ),
    .PARITY( "NONE" ),
    .STOP_BITS( 1 ))
uart_ttl (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart_rx_d),
    .uart_rx_dv(uart_rx_dv),
    .parity_ok(),
    .uart_tx_d(uart_tx_d),
    .uart_tx_dv(uart_tx_dv),
    .uart_tx_dr(uart_tx_dr),
    .uart_rx(UART_RX),
    .uart_tx(UART_TX)
    );

localparam RX_FIFO = 8;

wire [7:0] uart_io_rx_d;
wire uart_io_rx_dv;
reg  uart_io_rx_dr = 1;
wire uart_rx_fifo_nz;
reg  [7:0] uart_io_tx_d = 0;
reg  uart_io_tx_dv = 0;
wire uart_io_tx_dr;

uart_io #(
    .PROMPT( "ECP5>" ),
    .NR_BITS( NR_BITS ),
    .SKIP_SPACE( 0 ),
    .RX_FIFO( RX_FIFO ))
console (
    .clk(clk),
    .rst_n(rst_n),
    .uart_io_rx_d(uart_io_rx_d),
    .uart_io_rx_dv(uart_io_rx_dv),
    .uart_io_rx_dr(uart_io_rx_dr),
    .parity_io_ok(),
    .rx_fifo_nz(uart_rx_fifo_nz),
    .uart_io_tx_d(uart_io_tx_d),
    .uart_io_tx_dv(uart_io_tx_dv),
    .uart_io_tx_dr(uart_io_tx_dr),
    .uart_rx_d(uart_rx_d),
    .uart_rx_dv(uart_rx_dv),
    .parity_ok(),
    .uart_tx_d(uart_tx_d),
    .uart_tx_dv(uart_tx_dv),
    .uart_tx_dr(uart_tx_dr)
    );

wire mdio_clk;
reg  s_mdio_pa = 0;
reg  [4:0] s_mdio_ra = 0;
reg  [15:0] s_mdio_d = 0;
reg  s_mdio_dv = 0;
wire s_mdio_dr;
reg  s_mdio_rd = 0;
wire [15:0] m_mdio_d;
wire m_mdio_dv;
wire [1:0] mdc;
wire [1:0] mdio;

phy_mdio #(
    .NR_PHY( 2 ),
    .PREAMBLE( 1 ),
    .TL_BIDIR( 0 ),
    .PARALLEL( 1 ))
mdio_gpy111 (
    .clk(clk),
    .rst_n(rst_n),
    .mdio_clk(mdio_clk),
    .s_mdio_pa(s_mdio_pa),
    .s_mdio_ra(s_mdio_ra),
    .s_mdio_d(s_mdio_d),
    .s_mdio_dv(s_mdio_dv),
    .s_mdio_dr(s_mdio_dr),
    .s_mdio_rd(s_mdio_rd),
    .m_mdio_pa(5'd0),
    .m_mdio_d(m_mdio_d),
    .m_mdio_dv(m_mdio_dv),
    .mdc(mdc),
    .mdio(mdio),
    .mdio_i(),
    .mdio_o(),
    .mdio_oe()
    );

wire phy1_rx_clk;
wire [7:0] phy1_rx_d;
reg  [7:0] rx1_data = 0;
wire phy1_rx_dv;
wire rx1_er;
reg rx1_error = 0;
wire phy1_tx_clk;
reg  [7:0] phy1_tx_d = 0;
reg  phy1_tx_dv = 0;
reg  [7:0] tx1_d = 0;
reg  tx1_dv = 0;
reg  tx1_dv_i = 0;
wire link_up;

phy_100Mb #(
    .CFG_MODE( "RGMII" ))
phy1 (
    .clk(clk),
    .rx_clk(phy1_rx_clk),
    .rx_d(phy1_rx_d),
    .rx_dv(phy1_rx_dv),
    .rx_er(rx1_er),
    .tx_clk(phy1_tx_clk),
    .tx_d(phy1_tx_d),
    .tx_dv(phy1_tx_dv),
    .phy_rx_clk(PHY1_RGMII_RXCLK),
    .phy_rxd(PHY1_RGMII_RXD),
    .phy_rgmii_rx_ctrl(PHY1_RGMII_RXCTL),
    .phy_mii_rx_dv(),
    .phy_mii_rx_er(),
    .phy_mii_tx_clk(PHY1_RGMII_RXCLK), // TXCLK = RXCLK
    .phy_rmii_clk(),
    .phy_rgmii_tx_clk(PHY1_RGMII_TXCLK),
    .phy_txd(PHY1_RGMII_TXD),
    .phy_mii_tx_en(),
    .phy_rgmii_tx_ctrl(PHY1_RGMII_TXCTL)
    );

assign PHY1_RST_N = rst_n;
assign PHY1_MDC = mdc[0];
assign PHY1_MDIO = mdio[0];
assign PHY1_CONFIG = 0;

wire phy2_rx_clk;
wire [7:0] phy2_rx_d;
reg  [7:0] rx2_data = 0;
wire phy2_rx_dv;
wire rx2_er;
reg rx2_error = 0;
wire phy2_tx_clk;
reg  [7:0] phy2_tx_d = 0;
reg  phy2_tx_dv = 0;

phy_100Mb #(
    .CFG_MODE( "RGMII" ))
phy2 (
    .clk(clk),
    .rx_clk(phy2_rx_clk),
    .rx_d(phy2_rx_d),
    .rx_dv(phy2_rx_dv),
    .rx_er(rx2_er),
    .tx_clk(phy2_tx_clk),
    .tx_d(phy2_tx_d),
    .tx_dv(phy2_tx_dv),
    .phy_rx_clk(PHY2_RGMII_RXCLK),
    .phy_rxd(PHY2_RGMII_RXD),
    .phy_rgmii_rx_ctrl(PHY2_RGMII_RXCTL),
    .phy_mii_rx_dv(),
    .phy_mii_rx_er(),
    .phy_mii_tx_clk(PHY2_RGMII_RXCLK), // TXCLK = RXCLK
    .phy_rmii_clk(),
    .phy_rgmii_tx_clk(PHY2_RGMII_TXCLK),
    .phy_txd(PHY2_RGMII_TXD),
    .phy_mii_tx_en(),
    .phy_rgmii_tx_ctrl(PHY2_RGMII_TXCTL)
    );

assign PHY2_RST_N = rst_n;
assign PHY2_MDC = mdc[1];
assign PHY2_MDIO = mdio[1];
assign PHY2_CONFIG = 0;

wire rx0_loopback;
wire rx1_loopback;

wire [7:0] tx0m_d;
wire  tx0m_dv;
wire phy1_pre_dr;
wire [7:0] phy1_pre_d;
wire phy1_pre_dv;
reg  [7:0] tx0u_d = 0;
reg  tx0u_dv = 0;
reg  tx0u_dv_i = 0;
wire tx0m_clk;

/*============================================================================*/
sr2cb_m_phy_pre phy1_pre(
/*============================================================================*/
    .clk(tx0m_clk),
    .rst_n(rst_n),
    .rx_d(tx0m_dv ? tx0m_d : tx0u_d),
    .rx_dv(rx0_loopback ? 1'b0 : (tx0m_dv | tx0u_dv)), // RX0 loopback
    .rx_dr(phy1_pre_dr),
    .tx_d(phy1_pre_d),
    .tx_dv(phy1_pre_dv)
);

wire [7:0] tx1m_d;
wire tx1m_dv;
wire phy2_pre_dr;
reg  [7:0] tx1u_d = 0;
reg  tx1u_dv = 0;
reg  tx1u_dv_i = 0;
wire [7:0] phy2_pre_d;
wire phy2_pre_dv;
wire tx1m_clk;

/*============================================================================*/
sr2cb_m_phy_pre phy2_pre(
/*============================================================================*/
    .clk(tx1m_clk),
    .rst_n(rst_n),
    .rx_d(tx1m_dv ? tx1m_d : tx1u_d),
    .rx_dv(rx1_loopback ? 1'b0 : (tx1m_dv | tx1u_dv)), // RX1 loopback
    .rx_dr(phy2_pre_dr),
    .tx_d(phy2_pre_d),
    .tx_dv(phy2_pre_dv)
);

/*---------------------------*/
reg  rx0tx0_link = 0;
wire tx0m_err;
reg  rx1tx1_link = 0;
wire tx1m_err;
reg  [7:0] rx0m_ch_d = 0;
reg  rx0m_ch_dv = 0;
wire rx0m_ch_dr;
wire [7:0] tx0m_ch_d;
wire [CHW-1:0] rx0m_tx0_ch;
reg  [7:0] rx1m_d = 0;
reg  rx1m_dv = 0;
reg  [7:0] rx1m_ch_d = 0;
reg  rx1m_ch_dv = 0;
wire rx1m_ch_dr;
wire [7:0] tx1m_ch_d;
wire [CHW-1:0] rx1m_tx1_ch;
wire tx0rx0_valid;
wire [12:0] rx0m_node_pos;
wire [13:0] rx0m_c_s;
wire [2:0] rx0m_status;
wire [27:0] rx0m_delay;
wire tx1rx1_valid;
wire [12:0] rx1m_node_pos;
wire [13:0] rx1m_c_s;
wire [2:0] rx1m_status;
wire [27:0] rx1m_delay;
wire [2:0] tx0m_status;
reg  [12:0] tx0m_c_s = 0;
wire [2:0] tx1m_status;
reg  [12:0] tx1m_c_s = 0;
wire ring_reset_pending;
wire [63:0] clk_m_count;
wire [1:0] dv_m_en;
/*---------------------------*/
wire rx0s_clk[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] rx0s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire rx0s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_clk[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] tx0s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_err[0:NR_SR2CB_SLAVE_NODES-1];
wire rx1s_clk[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] rx1s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire rx1s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx1s_clk[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] tx1s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire tx1s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx1s_err[0:NR_SR2CB_SLAVE_NODES-1];
reg  [7:0] rx0s_ch_d[0:NR_SR2CB_SLAVE_NODES-1];
reg  rx0s_ch_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire rx0s_ch_dr[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] tx0s_ch_d[0:NR_SR2CB_SLAVE_NODES-1];
wire [CHW-1:0] rx0s_tx0_ch[0:NR_SR2CB_SLAVE_NODES-1];
reg  [7:0] rx1s_ch_d[0:NR_SR2CB_SLAVE_NODES-1];
reg  rx1s_ch_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire rx1s_ch_dr[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] tx1s_ch_d[0:NR_SR2CB_SLAVE_NODES-1];
wire [CHW-1:0] rx1s_tx1_ch[0:NR_SR2CB_SLAVE_NODES-1];
wire [12:0] rx0s_node_pos[0:NR_SR2CB_SLAVE_NODES-1];
wire [13:0] rx0s_c_s[0:NR_SR2CB_SLAVE_NODES-1];
wire [2:0] rx0s_status[0:NR_SR2CB_SLAVE_NODES-1];
wire [27:0] rx0s_delay[0:NR_SR2CB_SLAVE_NODES-1];
wire [67:0] rx0s_rt_clk_count[0:NR_SR2CB_SLAVE_NODES-1];
wire rx0_clk_adjust_fast[0:NR_SR2CB_SLAVE_NODES-1];
wire [12:0] rx1s_node_pos[0:NR_SR2CB_SLAVE_NODES-1];
wire [13:0] rx1s_c_s[0:NR_SR2CB_SLAVE_NODES-1];
wire [2:0] rx1s_status[0:NR_SR2CB_SLAVE_NODES-1];
wire [27:0] rx1s_delay[0:NR_SR2CB_SLAVE_NODES-1];
wire [67:0] rx1s_rt_clk_count[0:NR_SR2CB_SLAVE_NODES-1];
wire rx1_clk_adjust_fast[0:NR_SR2CB_SLAVE_NODES-1];
wire [3:0] clk_s_en[0:NR_SR2CB_SLAVE_NODES-1];
wire [3:0] dv_s_en[0:NR_SR2CB_SLAVE_NODES-1];

integer k = 0;
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( k = 0; k < NR_SR2CB_SLAVE_NODES; k = k + 1 ) begin
        rx0s_ch_d[k] = 0;
        rx0s_ch_dv[k] = 0;
        rx1s_ch_d[k] = 0;
        rx1s_ch_dv[k] = 0;
    end
end

assign link_up = rx0tx0_link | rx1tx1_link;

/*============================================================================*/
sr2cb_m #( .NR_CHANNELS( NR_CHANNELS )) master_node(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0tx0_link(rx0tx0_link), // Link up status set by terminal console
    .rx0_loopback(rx0_loopback),
    .rx0_clk(phy1_rx_clk),
    .rx0_d(phy1_rx_d),
    .rx0_dv(phy1_rx_dv & link_up),
    .rx0_err(1'b0),
    .tx0_clk(tx0m_clk),
    .tx0_d(tx0m_d),
    .tx0_dv(tx0m_dv),
    .tx0_dr(phy1_pre_dr),
    .tx0_err(tx0m_err),
    .rx1tx1_link(rx1tx1_link), // Link up status set by terminal console
    .rx1_loopback(rx1_loopback),
    .rx1_clk(phy1_rx_clk),
    .rx1_d(rx1m_d),
    .rx1_dv(rx1m_dv),
    .rx1_err(1'b0),
    .tx1_clk(tx1m_clk),
    .tx1_d(tx1m_d),
    .tx1_dv(tx1m_dv),
    .tx1_dr(phy2_pre_dr),
    .tx1_err(tx1m_err),
    .rx0_ch_d(rx0m_ch_d),
    .rx0_ch_dv(rx0m_ch_dv),
    .rx0_ch_dr(rx0m_ch_dr),
    .tx0_ch_d(tx0m_ch_d),
    .rx0_tx0_ch(rx0m_tx0_ch),
    .rx1_ch_d(rx1m_ch_d),
    .rx1_ch_dv(rx1m_ch_dv),
    .rx1_ch_dr(rx1m_ch_dr),
    .tx1_ch_d(tx1m_ch_d),
    .rx1_tx1_ch(rx1m_tx1_ch),
    .tx0rx0_valid(tx0rx0_valid),
    .rx0_node_pos(rx0m_node_pos),
    .rx0_c_s(rx0m_c_s),
    .rx0_status(rx0m_status),
    .rx0_delay(rx0m_delay),
    .tx1rx1_valid(tx1rx1_valid),
    .rx1_node_pos(rx1m_node_pos),
    .rx1_c_s(rx1m_c_s),
    .rx1_status(rx1m_status),
    .rx1_delay(rx1m_delay),
    .tx0_status(tx0m_status),
    .tx0_c_s(tx0m_c_s),
    .tx1_status(tx1m_status),
    .tx1_c_s(tx1m_c_s),
    .ring_reset_pending(ring_reset_pending),
    .clk_count(clk_m_count),
    .dv_en(dv_m_en)
);

/*=============================================================================/
RING         | SLV0    |  | SLV1    |         | SLV8190 |  | SLV8191 |
|  +------+  +---------+  +---------+         +---------+  +---------+  +------+
|  |MASTER|  | NP 8191 |  | NP 8190 |         | NP 1    |  | NP 0    |  |MASTER|
CCW|  RX0 |<-| TX0 RX1 |<-| TX0 RX1 |<- - - <-| TX0 RX1 |<-| TX0 RX1 |<-| TX1  |
|  |      |  | NP 0    |    NP 1    |         | NP 8190 |    NP 8191 |  |      |
CW |  TX0 |->| RX0 TX1 |->| RX0 TX1 |->- - ->-| RX0 TX1 |->| RX0 TX1 |->| RX1  |
   +------+  +---------+  +---------+         +---------+  +---------+  +------+
/=============================================================================*/

// RX0/RX1 loopback related assignments, no TX0/TX1 preamble and SFD generation!
wire [7:0] tx0mp_d;
assign tx0mp_d = rx0_loopback ? tx0m_d : phy1_pre_d;
wire tx0mp_dv;
assign tx0mp_dv = rx0_loopback ? tx0m_dv : phy1_pre_dv;
wire [7:0] tx1mp_d;
assign tx1mp_d = rx1_loopback ? tx1m_d : phy2_pre_d;
wire tx1mp_dv;
assign tx1mp_dv = rx1_loopback ? tx1m_dv : phy2_pre_dv;

genvar a;
generate
    assign rx0s_clk[0] = phy2_rx_clk;
    assign rx0s_d[0] = phy2_rx_d;
    assign rx0s_dv[0] = phy2_rx_dv & link_up;
    for ( a = 1; a < NR_SR2CB_SLAVE_NODES; a = a + 1 ) begin
        assign rx0s_clk[a] = tx1s_clk[a-1];
        assign rx0s_d[a] = tx1s_d[a-1];
        assign rx0s_dv[a] = tx1s_dv[a-1];
    end
    assign rx1s_clk[NR_SR2CB_SLAVE_NODES-1] = tx1m_clk;
    assign rx1s_d[NR_SR2CB_SLAVE_NODES-1] = tx1mp_d;
    assign rx1s_dv[NR_SR2CB_SLAVE_NODES-1] = tx1mp_dv;
    for ( a = 0; a < ( NR_SR2CB_SLAVE_NODES - 1 ); a = a + 1 ) begin
        assign rx1s_clk[a] = tx0s_clk[a+1];
        assign rx1s_d[a] = tx0s_d[a+1];
        assign rx1s_dv[a] = tx0s_dv[a+1];
    end
endgenerate

genvar b;
generate
for ( b = 0; b < NR_SR2CB_SLAVE_NODES; b = b + 1 ) begin : slave_node
/*============================================================================*/
sr2cb_s #( .NR_CHANNELS( NR_CHANNELS )) slvn (
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0_clk(phy2_rx_clk),
    .rx0_d(rx0s_d[b]),
    .rx0_dv(rx0s_dv[b]),
    .rx0_err(1'b0),
    .tx0_clk(tx0s_clk[b]),
    .tx0_d(tx0s_d[b]),
    .tx0_dv(tx0s_dv[b]),
    .tx0_dr(1'b1),
    .tx0_err(tx0s_err[b]),
    .rx1_clk(phy1_rx_clk), // Different clock than rx0_clk to test CDC
    .rx1_d(rx1s_d[b]),
    .rx1_dv(rx1s_dv[b]),
    .rx1_err(1'b0),
    .tx1_clk(tx1s_clk[b]),
    .tx1_d(tx1s_d[b]),
    .tx1_dv(tx1s_dv[b]),
    .tx1_dr(1'b1),
    .tx1_err(tx1s_err[b]),
    .rx0_ch_d(rx0s_ch_d[b]),
    .rx0_ch_dv(rx0s_ch_dv[b]),
    .rx0_ch_dr(rx0s_ch_dr[b]),
    .tx0_ch_d(tx0s_ch_d[b]),
    .rx0_tx0_ch(rx0s_tx0_ch[b]),
    .rx1_ch_d(rx1s_ch_d[b]),
    .rx1_ch_dv(rx1s_ch_dv[b]),
    .rx1_ch_dr(rx1s_ch_dr[b]),
    .tx1_ch_d(tx1s_ch_d[b]),
    .rx1_tx1_ch(rx1s_tx1_ch[b]),
    .rx0_node_pos(rx0s_node_pos[b]),
    .rx0_c_s(rx0s_c_s[b]),
    .rx0_status(rx0s_status[b]),
    .rx0_delay(rx0s_delay[b]),
    .rx0_rt_clk_count(rx0s_rt_clk_count[b]),
    .rx0_clk_adjust_fast(rx0_clk_adjust_fast[b]),
    .rx1_node_pos(rx1s_node_pos[b]),
    .rx1_c_s(rx1s_c_s[b]),
    .rx1_status(rx1s_status[b]),
    .rx1_delay(rx1s_delay[b]),
    .rx1_rt_clk_count(rx1s_rt_clk_count[b]),
    .rx1_clk_adjust_fast(rx1_clk_adjust_fast[b]),
    .clk_en(clk_s_en[b]),
    .dv_en(dv_s_en[b])
);
end
endgenerate

reg [3:0] rst_count = 0;
assign rst_n = &rst_count; // Synchronous reset!

/*============================================================================*/
always @(posedge clk or negedge ARST_N) begin : reset_counter
/*============================================================================*/
    if ( !ARST_N ) begin
        rst_count <= 0;
    end else if ( !rst_n ) begin
        rst_count <= rst_count + 1;
    end
end

reg [25:0] clk_count = 0;
assign DP  = clk_count[25]; // Heart beat

/*============================================================================*/
always @(posedge clk or negedge ARST_N) begin : clock_counter
/*============================================================================*/
    if ( !ARST_N ) begin
        clk_count <= 0;
    end else begin
        clk_count <= clk_count + 1;
    end
end

// assign mdio_clk = clk_count[2]; // 12.5MHz
// assign mdio_clk = clk_count[3]; // 6.25MHz
assign mdio_clk = clk_count[4]; // 3.125MHz Marvell PHY 88E1512 MDC < 5MHz!

localparam RXFW = clog2( RX_FIFO );

reg [RXFW:0] u_rx_count = 0; // +1
reg [7:0] u_rxd;
reg [7:0] u_rxd_cmd = 0;
reg [15:0] u_rxd_param = 0;
reg [15:0] u_txd = 0;
reg [2:0] u_tx_count = 0;
reg u_rx_end = 0;
reg u_tx_enable = 0;

wire u_rxd_0_9;
assign u_rxd_0_9 = (( uart_io_rx_d >= "0" ) && ( uart_io_rx_d <= "9" ));
wire u_rxd_a_f;
assign u_rxd_a_f = (( uart_io_rx_d >= "a" ) && ( uart_io_rx_d <= "f" ));
wire u_rxd_A_F;
assign u_rxd_A_F = (( uart_io_rx_d >= "A" ) && ( uart_io_rx_d <= "F" ));
wire u_txd_0_9;
assign u_txd_0_9 = ( u_txd[15:12] < 4'hA );

/*============================================================================*/
always @(*) begin : atoi_uart_rxd
/*============================================================================*/
    u_rxd = 0;
    if ( u_rxd_0_9 ) begin
        u_rxd = uart_io_rx_d - "0";
    end
    if ( u_rxd_a_f ) begin
        u_rxd = uart_io_rx_d - "a" + 8'h0A;
    end
    if ( u_rxd_A_F ) begin
        u_rxd = uart_io_rx_d - "A" + 8'h0A;
    end
end // atoi_uart_rxd

localparam [7:0] CR = 8'h0D;

/*============================================================================*/
always @(posedge clk) begin : uart_cmd
/*============================================================================*/
    s_mdio_dv <= s_mdio_dv & s_mdio_dr;
    tx0u_dv_i <= tx0u_dv_i & ~( tx0u_dv & tx0u_dv_i );
    tx1u_dv_i <= tx1u_dv_i & ~( tx1u_dv & tx1u_dv_i );
    u_rx_end <= 0;
    if ( uart_io_rx_dv && uart_io_rx_dr ) begin
        if ( u_rxd_0_9 || u_rxd_a_f || u_rxd_A_F ) begin
            if ( 0 == u_rx_count ) begin
                u_rxd_cmd[7:4] <= u_rxd[3:0]; // Set upper nibble
            end
            if ( 1 == u_rx_count ) begin
                u_rxd_cmd[3:0] <= u_rxd[3:0]; // Set lower nibble
            end
            if ( 2 == u_rx_count ) begin
                u_rxd_param[15:12] <= u_rxd[3:0]; // Set upper nibble high byte word
            end
            if ( 3 == u_rx_count ) begin
                u_rxd_param[11:8] <= u_rxd[3:0]; // Set lower nibble high byte word
            end
            if ( 4 == u_rx_count ) begin
                u_rxd_param[7:4] <= u_rxd[3:0]; // Set upper nibble low byte word
            end
            if ( 5 == u_rx_count ) begin
                u_rxd_param[3:0] <= u_rxd[3:0]; // Set lower nibble low byte word
            end
            u_rx_count <= u_rx_count + 1;
        end
        u_rx_end <= ~uart_rx_fifo_nz;
    end
    if ( u_rx_end && s_mdio_dr ) begin
        case ( u_rxd_cmd[7:6] )
        2'b00 : begin // MDIO registers 0x00-0x1F, 2 PHYs (0x00, 0x20)
            if ( 2 == u_rx_count ) begin
                s_mdio_pa <= u_rxd_cmd[5];
                s_mdio_ra <= u_rxd_cmd[4:0];
                s_mdio_rd <= 1; // Read MDIO
                s_mdio_dv <= 1;
            end
            if ( 6 == u_rx_count ) begin
                s_mdio_pa <= u_rxd_cmd[5];
                s_mdio_ra <= u_rxd_cmd[4:0];
                s_mdio_rd <= 0; // Write MDIO
                s_mdio_d <= u_rxd_param;
                s_mdio_dv <= 1;
            end
        end
        2'b01 : begin // PHY RX/TX (0x40, 0x60)
            if ( 2 == u_rx_count ) begin // RX
                u_txd <= {rx1_error, 7'd0, rx1_data}; // PHY1
                if ( u_rxd_cmd[5] ) begin // PHY2
                    u_txd <= {rx2_error, 7'd0, rx2_data};
                end
                u_txd[15] <= rx1tx1_link;
                u_txd[14] <= rx0tx0_link;
                u_txd[13] <= rx1_loopback;
                u_txd[12] <= rx0_loopback;
                u_tx_enable <= 1;
            end
            if ( 4 == u_rx_count ) begin // TX
                if ( u_rxd_cmd[5] ) begin // PHY2
                    tx1u_dv_i <= 1;
                    tx1u_d <= u_rxd_param[15:8];
                end else begin // PHY1
                    tx0u_dv_i <= 1;
                    tx0u_d <= u_rxd_param[15:8];
                end
            end
        end
        2'b10 : begin
            case ( u_rxd_cmd[5:0] )
            6'h00 : begin // PHY link up (0x80), read R0 status
                if ( 2 == u_rx_count ) begin // R0 status
                    u_txd[15:12] <= tx0m_status;
                    u_txd[11:8] <= rx0s_status[0];
                    u_txd[7:4] <= rx0s_status[1];
                    u_txd[3:0] <= rx0s_status[2];
                    u_tx_enable <= 1;
                end
                if ( 3 == u_rx_count ) begin // PHY link up
                    rx1tx1_link <= u_rxd_param[13];
                    rx0tx0_link <= u_rxd_param[12]; // Upper nibble word!
                end
            end
            6'h01 : begin // Read R1 status (0x81)
                if ( 2 == u_rx_count ) begin // R1 status
                    u_txd[15:12] <= tx1m_status;
                    u_txd[11:8] <= rx1s_status[0];
                    u_txd[7:4] <= rx1s_status[1];
                    u_txd[3:0] <= rx1s_status[2];
                    u_tx_enable <= 1;
                end
            end
            6'h02 : begin // Read CLK enable debug signals (0x82)
                if ( 2 == u_rx_count ) begin
                    u_txd[15:12] <= 4'h9; // Master clock always enabled
                    u_txd[11:8] <= clk_s_en[0];
                    u_txd[7:4] <= clk_s_en[1];
                    u_txd[3:0] <= clk_s_en[2];
                    u_tx_enable <= 1;
                end
            end
            6'h03 : begin // Read DV debug signals (0x83)
                if ( 2 == u_rx_count ) begin
                    u_txd[15:12] <= {dv_m_en[1], 2'b0, dv_m_en[0]};
                    u_txd[11:8] <= dv_s_en[0];
                    u_txd[7:4] <= dv_s_en[1];
                    u_txd[3:0] <= dv_s_en[2];
                    u_tx_enable <= 1;
                end
            end
            6'h10 : begin // Read last UART RXD data (0x90)
                if ( 2 == u_rx_count ) begin
                    u_txd <= u_rxd_param;
                    u_tx_enable <= 1;
                end
            end
            endcase
        end
        endcase
        u_rx_count <= 0;
        u_tx_count <= 0;
    end
    uart_io_tx_dv <= 0;
    if ( u_tx_enable ) begin
        if ( uart_io_tx_dr && !uart_io_tx_dv ) begin
            uart_io_tx_d <= {4'h0, u_txd[15:12]} + ( u_txd_0_9 ? "0" : ( "A" - 8'h0A ));
            uart_io_tx_dv <= 1;
            if ( 4 == u_tx_count ) begin
                uart_io_tx_d <= CR;
                u_tx_enable <= 0;
            end else begin
                u_tx_count <= u_tx_count + 1;
            end
            u_txd <= {u_txd[11:0], 4'h0};
        end
    end if ( m_mdio_dv  ) begin
        u_txd <= m_mdio_d;
        u_tx_enable <= 1;
        u_tx_count <= 0;
    end
    if ( !rst_n ) begin
        uart_io_rx_dr <= 1;
        s_mdio_rd <= 0;
        s_mdio_dv <= 0;
        u_tx_enable <= 0;
    end
end // uart_cmd

reg [22:0] phy1_rx_clk_count = 0;
/*============================================================================*/
always @(posedge phy1_rx_clk) begin : phy1_rx_process
/*============================================================================*/
    rx1m_d <= tx1s_d[NR_SR2CB_SLAVE_NODES-1]; // Synchronize
    rx1m_dv <= tx1s_dv[NR_SR2CB_SLAVE_NODES-1];
    if ( phy1_rx_dv ) begin
        rx1_data <= phy1_rx_d;
        rx1_error <= rx1_er;
    end
    phy1_rx_clk_count <= phy1_rx_clk_count + 1;
end // phy1_rx_process

/*============================================================================*/
always @(posedge phy1_tx_clk) begin : phy1_tx_process
/*============================================================================*/
    phy1_tx_d <= tx0mp_d; // Synchronize
    phy1_tx_dv <= tx0mp_dv;
end // phy1_tx_process

/*============================================================================*/
always @(posedge tx0m_clk) begin : master_tx_process
/*============================================================================*/
    tx0u_dv <= tx0u_dv_i;
end // master_tx_process

reg [22:0] phy2_rx_clk_count = 0;
/*============================================================================*/
always @(posedge phy2_rx_clk) begin : phy2_rx_process
/*============================================================================*/
    if ( phy2_rx_dv ) begin
        rx2_data <= phy2_rx_d;
        rx2_error <= rx2_er;
    end
    phy2_rx_clk_count <= phy2_rx_clk_count + 1;
end // phy2_rx_process

/*============================================================================*/
always @(posedge phy2_tx_clk) begin : phy2_tx_process
/*============================================================================*/
    phy2_tx_d <= tx0s_d[0]; // Synchronize
    phy2_tx_dv <= tx0s_dv[0];
end // phy2_tx_process

/*============================================================================*/
always @(posedge tx0s_clk[0]) begin : slave0_tx_process
/*============================================================================*/
    tx1u_dv <= tx1u_dv_i;
end // slave0_tx_process

integer i;
reg [NR_SR2CB_SLAVE_NODES:0] ring0_ready;
reg [NR_SR2CB_SLAVE_NODES:0] ring1_ready;
/*============================================================================*/
always @(*) begin : ring_status
/*============================================================================*/
    // Slave nodes
    for ( i = 0; i < NR_SR2CB_SLAVE_NODES; i = i + 1 ) begin
        ring0_ready[i] = ( `eR_READY == rx0s_status[i] );
        ring1_ready[i] = ( `eR_READY == rx1s_status[i] );
    end
    // Master node
    ring0_ready[NR_SR2CB_SLAVE_NODES] = ( `eR_READY == tx0m_status );
    ring1_ready[NR_SR2CB_SLAVE_NODES] = ( `eR_READY == tx1m_status );
end // ring_status

assign LED[7:4] = 4'hF; // 1 = off
assign LED[1:0] = 2'b11; // 1 = off
assign SEG[13:12] = 2'b11; // 1 = 0ff
assign SEG[10:8] = 3'h7; // 1 = 0ff
assign SEG[6:0] = 7'h7F; // 1 = 0ff

assign LED[2] = ~&ring0_ready; // Green LEDs
assign LED[3] = ~&ring1_ready;
assign SEG[7] = phy1_rx_clk_count[22]; // h-segment
assign SEG[11] = phy2_rx_clk_count[22]; // m-segment

endmodule // ecp5_sr2cb
