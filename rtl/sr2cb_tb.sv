/**
 *  Copyright (C) 2024, Kees Krijnen.
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
 *  Description:
 *
 *  Documents the SR2CB specification by simulation of the SR2CB protocol. The
 *  simulation is setup by SR2CB ring slave nodes clockwise and counterclockwise
 *  byte transfers initiated by a SR2CB master node. The test bench acts as a
 *  (soft core) CPU - system controller.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "../sr2cb_m_phy_pre.v"
// `include "../sr2cb_m.v"
// `include "../sr2cb_s.v"
`include "sr2cb_def.v"

/*============================================================================*/
module sr2cb_tb;
/*============================================================================*/
localparam NR_CHANNELS = 4;
localparam NR_SR2CB_SLAVE_NODES = 3;
localparam CHW = $clog2( NR_CHANNELS );

reg  clk = 0;
reg  rst_n = 0;
reg  rxtx_clk = 0;
/*---------------------------*/
reg  rx0tx0_link = 0;
wire [7:0] tx0m_d;
wire tx0m_dv;
wire tx0m_err;
wire tx0m_clk;
reg  rx1tx1_link = 0;
wire [7:0] tx1m_d;
wire tx1m_dv;
wire tx1m_err;
wire tx1m_clk;
reg  [7:0] rx0m_ch_d = 0;
reg  rx0m_ch_dv = 0;
wire rx0m_ch_dr;
wire [7:0] tx0m_ch_d;
wire [CHW-1:0] rx0m_tx0_ch;
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
/*---------------------------*/
wire [7:0] phy_pre_0_d;
wire phy_pre_0_dv;
wire phy_pre_0_dr;
/*---------------------------*/
wire [7:0] phy_pre_1_d;
wire phy_pre_1_dv;
wire phy_pre_1_dr;
/*---------------------------*/
wire [7:0] rx0s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire rx0s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_clk[0:NR_SR2CB_SLAVE_NODES-1];
wire [7:0] tx0s_d[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_dv[0:NR_SR2CB_SLAVE_NODES-1];
wire tx0s_err[0:NR_SR2CB_SLAVE_NODES-1];
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

wire [7:0] tx0s0_d;
assign tx0s0_d = tx0s_d[0];
wire tx0s0_dv;
assign tx0s0_dv = tx0s_dv[0];
wire [7:0] tx1s0_d;
assign tx1s0_d = tx1s_d[NR_SR2CB_SLAVE_NODES-1];
wire tx1s0_dv;
assign tx1s0_dv = tx1s_dv[NR_SR2CB_SLAVE_NODES-1];
wire rx0_loopback;
wire rx1_loopback;

/*============================================================================*/
sr2cb_m #( .NR_CHANNELS( NR_CHANNELS )) master_node(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0tx0_link(rx0tx0_link), // Actual link status provided by PHY device
    .rx0_loopback(rx0_loopback),
    .rx0_clk(rxtx_clk),
    .rx0_d(tx0s0_d),
    .rx0_dv(tx0s0_dv),
    .rx0_err(1'b0),
    .tx0_clk(tx0m_clk),
    .tx0_d(tx0m_d),
    .tx0_dv(tx0m_dv),
    .tx0_dr(phy_pre_0_dr),
    .tx0_err(tx0m_err),
    .rx1tx1_link(rx1tx1_link), // Actual link status provided by PHY device
    .rx1_loopback(rx1_loopback),
    .rx1_clk(rxtx_clk),
    .rx1_d(tx1s0_d),
    .rx1_dv(tx1s0_dv),
    .rx1_err(1'b0),
    .tx1_clk(tx1m_clk),
    .tx1_d(tx1m_d),
    .tx1_dv(tx1m_dv),
    .tx1_dr(phy_pre_1_dr),
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
    .clk_count(clk_m_count)
);

/*============================================================================*/
sr2cb_m_phy_pre phy_pre_0(
/*============================================================================*/
    .clk(rxtx_clk),
    .rst_n(rst_n),
    .rx_d(tx0m_d),
    .rx_dv(rx0_loopback ? 1'b0 : tx0m_dv), // RX0 loopback
    .rx_dr(phy_pre_0_dr),
    .tx_d(phy_pre_0_d),
    .tx_dv(phy_pre_0_dv)
);

/*============================================================================*/
sr2cb_m_phy_pre phy_pre_1(
/*============================================================================*/
    .clk(rxtx_clk),
    .rst_n(rst_n),
    .rx_d(tx1m_d),
    .rx_dv (rx1_loopback ? 1'b0 : tx1m_dv), // RX1 loopback
    .rx_dr(phy_pre_1_dr),
    .tx_d(phy_pre_1_d),
    .tx_dv(phy_pre_1_dv)
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
assign tx0mp_d = rx0_loopback ? tx0m_d : phy_pre_0_d;
wire tx0mp_dv;
assign tx0mp_dv = rx0_loopback ? tx0m_dv : phy_pre_0_dv;
wire [7:0] tx1mp_d;
assign tx1mp_d = rx1_loopback ? tx1m_d : phy_pre_1_d;
wire tx1mp_dv;
assign tx1mp_dv = rx1_loopback ? tx1m_dv : phy_pre_1_dv;

genvar a;
generate
    assign rx0s_d[0] = tx0mp_d;
    assign rx0s_dv[0] = tx0mp_dv;
    assign rx1s_d[NR_SR2CB_SLAVE_NODES-1] = tx1mp_d;
    assign rx1s_dv[NR_SR2CB_SLAVE_NODES-1] = tx1mp_dv;
    for ( a = 1; a < NR_SR2CB_SLAVE_NODES; a = a + 1 ) begin
        assign rx0s_d[a] = tx1s_d[a-1];
        assign rx0s_dv[a] = tx1s_dv[a-1];
    end
    for ( a = 0; a < ( NR_SR2CB_SLAVE_NODES - 1 ); a = a + 1 ) begin
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
    .rx0_clk(rxtx_clk),
    .rx0_d(rx0s_d[b]),
    .rx0_dv(rx0s_dv[b]),
    .rx0_err(1'b0),
    .tx0_clk(tx0s_clk[b]),
    .tx0_d(tx0s_d[b]),
    .tx0_dv(tx0s_dv[b]),
    .tx0_dr(1'b1),
    .tx0_err(tx0s_err[b]),
    .rx1_clk(rxtx_clk),
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
    .rx1_clk_adjust_fast(rx1_clk_adjust_fast[b])
);
end
endgenerate

always #5  clk = ~clk; // 100 MHz clock
always #40 rxtx_clk = ~rxtx_clk; // 12.5 MHz clock

reg [27:0] delay[0:NR_SR2CB_SLAVE_NODES-1][0:1]; // Delay received from all nodes

/*============================================================================*/
always @(posedge clk) begin : collect_delay
/*============================================================================*/
    if ( tx0rx0_valid ) begin
        if ( 0 == delay[rx0m_node_pos][0] ) begin
            delay[rx0m_node_pos][0] <= rx0m_delay;
        end
    end
    if ( tx1rx1_valid ) begin
        if ( 0 == delay[rx1m_node_pos][1] ) begin
            delay[rx1m_node_pos][1] <= rx1m_delay;
        end
    end
end // collect_delay

localparam MIDDLE_NODE = NR_SR2CB_SLAVE_NODES / 2;
localparam LAST_NODE = NR_SR2CB_SLAVE_NODES - 1;

integer i = 0;
integer j = 0;
reg passed = 0;
reg [0:0] rdir = `CW_RDIR;

/*============================================================================*/
task display_results ( input [0:0] ring_reset );
/*============================================================================*/
begin
    passed = 0;
    for ( i = 0; (( i < 500 ) && !passed ); i = i + 1 ) begin
        wait ( phy_pre_0_dr ) @( negedge phy_pre_0_dr );
        wait ( phy_pre_1_dr ) @( negedge phy_pre_1_dr );
        // Generated slave node instances are not addressable by index variable!
        passed = ( 0 == slave_node[0].slvn.rx0_mclk_delta ) && ( 0 == slave_node[0].slvn.rx1_mclk_delta );
        if ( passed && ( NR_SR2CB_SLAVE_NODES > 2 )) begin
            passed = ( 0 == slave_node[MIDDLE_NODE].slvn.rx0_mclk_delta ) &&
                     ( 0 == slave_node[MIDDLE_NODE].slvn.rx1_mclk_delta );
        end
        if ( passed && ( NR_SR2CB_SLAVE_NODES > 1 )) begin
            passed = ( 0 == slave_node[LAST_NODE].slvn.rx0_mclk_delta ) &&
                     ( 0 == slave_node[LAST_NODE].slvn.rx1_mclk_delta );
        end
    end
    if ( ring_reset ) begin
        $display( "Redundant ring reset, master clock = %0d",  clk_m_count );
    end else begin
        $display( "Master clock = %0d",  clk_m_count );
    end
    for ( i = 0; i < NR_SR2CB_SLAVE_NODES; i = i + 1 ) begin
        $display( "Slv_node[%0d], RX0 clock = %0d.%0d, RX1 clock = %0d.%0d", i, rx0s_rt_clk_count[i][67:4],
        rx0s_rt_clk_count[i][3:0], rx1s_rt_clk_count[i][67:4], rx1s_rt_clk_count[i][3:0] );
    end
    if ( !passed ) begin
        $display( "Slv_node[0], rx0_mclk_delta = %0d, rx1_mclk_delta = %0d", slave_node[0].slvn.rx0_mclk_delta,
            slave_node[0].slvn.rx1_mclk_delta );
        if ( NR_SR2CB_SLAVE_NODES > 2 ) begin
            $display( "Slv_node[%0d], rx0_mclk_delta = %0d, rx1_mclk_delta = %0d", MIDDLE_NODE,
                slave_node[MIDDLE_NODE].slvn.rx0_mclk_delta,
                slave_node[MIDDLE_NODE].slvn.rx1_mclk_delta );
        end
        if ( NR_SR2CB_SLAVE_NODES > 1 ) begin
            $display( "Slv_node[%0d], rx0_mclk_delta = %0d, rx1_mclk_delta = %0d", LAST_NODE,
                slave_node[LAST_NODE].slvn.rx0_mclk_delta,
                slave_node[LAST_NODE].slvn.rx1_mclk_delta );
        end
    end
    $display( "Clock synchronization R0 and R1 %s", ( passed ? "passed" : "failed" ));
    $display( "" );
end
endtask

/*============================================================================*/
task ring_init ( input [0:0] rdir, input integer nb_delay_samples );
/*============================================================================*/
begin
    case ( nb_delay_samples )
        1 : begin
            tx0m_c_s = `CLK_SYNC_0;
            tx1m_c_s = `CLK_SYNC_0;
        end
        2 : begin
            tx0m_c_s = `CLK_SYNC_1;
            tx1m_c_s = `CLK_SYNC_1;
        end
        4 : begin
            tx0m_c_s = `CLK_SYNC_2;
            tx1m_c_s = `CLK_SYNC_2;
        end
        8 : begin
            tx0m_c_s = `CLK_SYNC_3;
            tx1m_c_s = `CLK_SYNC_3;
        end
        default: begin // Same as 1 delay sample - `CLK_SYNC_0
            tx0m_c_s = 0;
            tx1m_c_s = 0;
        end
    endcase
    if ( rdir ) begin
        rx1tx1_link = 1;
        wait ( rxtx_clk ) @( negedge rxtx_clk );
        wait ( rxtx_clk ) @( negedge rxtx_clk );
        rx0tx0_link = 1;
        wait ( `eR_WAIT == tx1m_status );
    end else begin
        rx0tx0_link = 1;
        wait ( rxtx_clk ) @( negedge rxtx_clk );
        wait ( rxtx_clk ) @( negedge rxtx_clk );
        rx1tx1_link = 1;
        wait ( `eR_WAIT == tx0m_status );
    end
    passed = 1;
    for ( i = 0; i < NR_SR2CB_SLAVE_NODES; i = i + 1 ) begin
        $display( "delay[%0d][%0d] = %0d.%0d, slv_node[%0d] rx0_status = %0d",
            i, rdir, delay[i][rdir][27:4], delay[i][rdir][3:0], i, ( rdir ? rx1s_status[i] : rx0s_status[i] ));
        passed = passed && ( delay[i][rdir] > 0 ) && (( `eR_WAIT == ( rdir ? rx1s_status[i] : rx0s_status[i] )) ||
            ( `eR_READY == ( rdir ? rx1s_status[i] : rx0s_status[i] )));
    end
    $display( "Master node, tx0_status = %0d, tx1_status = %0d", tx0m_status, tx1m_status );
    $display( "Initialization R%0d %s", rdir, ( passed ? "passed" : "failed" ));
    $display( "" );
    if ( rdir ) begin
        wait ( `eR_READY == tx0m_status );
    end else begin
        wait ( `eR_READY == tx1m_status );
    end
    tx0m_c_s = 0;
    tx1m_c_s = 0;
    passed = 1;
    for ( i = NR_SR2CB_SLAVE_NODES; i > 0; i = i - 1 ) begin
        $display( "delay[%0d][%0d] = %0d.%0d, slv_node[%0d] rx0_status = %0d rx1_status = %0d",
            (i-1), ~rdir, delay[i-1][~rdir][27:4], delay[i-1][~rdir][3:0], (i-1), rx0s_status[i-1],  rx1s_status[i-1] );
        passed = passed && ( delay[i-1][~rdir] > 0 ) && ( `eR_READY == ( rdir ? rx1s_status[i-1] : rx0s_status[i-1] ));
    end
    $display( "Master node, tx0_status = %0d, tx1_status = %0d", tx0m_status, tx1m_status );
    $display( "Initialization R0 and R1 %s", ( passed ? "passed" : "failed" ));
    $display( "" );
    if ( rdir ) begin
        wait ( `eR_READY == rx0s_status[0] );
    end else begin
        wait ( `eR_READY == rx1s_status[NR_SR2CB_SLAVE_NODES-1] );
    end
    $display( "Master node R0/R1 master clock = %0d",  clk_m_count );
    for ( i = 0; i < NR_SR2CB_SLAVE_NODES; i = i + 1 ) begin
        $display( "Slv_node[%0d], RX0 clock = %0d.%0d, RX1 clock = %0d.%0d", i, rx0s_rt_clk_count[i][67:4],
        rx0s_rt_clk_count[i][3:0], rx1s_rt_clk_count[i][67:4], rx1s_rt_clk_count[i][3:0] );
    end
    $display( "" );
    wait ( master_node.rx0_clk_reset_cmd && master_node.rx1_clk_reset_cmd );
    $display( "M/S clocks reset, master clock = %0d",  clk_m_count );
    for ( i = 0; i < NR_SR2CB_SLAVE_NODES; i = i + 1 ) begin
        $display( "Slv_node[%0d], RX0 clock = %0d.%0d, RX1 clock = %0d.%0d", i, rx0s_rt_clk_count[i][67:4],
        rx0s_rt_clk_count[i][3:0], rx1s_rt_clk_count[i][67:4], rx1s_rt_clk_count[i][3:0] );
    end
    $display( "" );
    if ( rdir ) begin
        wait(( `MASTER_CLK_10L >> 10 ) == rx0m_c_s[13:10] );
    end else begin
        wait(( `MASTER_CLK_10L >> 10 ) == rx1m_c_s[13:10] );
    end
    tx0m_c_s = 13'hFFF; // Set unkown command to stop sending master clock status!
    tx1m_c_s = 13'hFFF;
    display_results( 0 );
end
endtask // ring_init

/*============================================================================*/
initial begin // Test bench
/*============================================================================*/
    rst_n  = 0;
    clk    = 0;
    passed = 0;
    rdir   = `CW_RDIR; // Select CW/CCW direction
    /*---------*/
    for ( j = 0; j < NR_SR2CB_SLAVE_NODES; j = j + 1 ) begin
        for ( i = 0; i < 2; i = i + 1 ) begin
            delay[j][i] = 0;
        end
    end
    #100 // 100ns
    $display( "SR2CB master/slave simulation started" );
    rst_n = 1;
    #100 // 100ns
    ring_init( rdir, 2 ); // Select CW/CCW direction, 0/1/2/4/8 delay samples!
    #1000 // 1us
    wait ( tx0m_dv ) @( negedge tx0m_dv );
    if ( rdir ) begin
        tx1m_c_s = `RING_RESET;
    end else begin
        tx0m_c_s = `RING_RESET;
    end
    if ( rdir ) begin
        wait( `RING_RESET == rx0m_c_s[12:0] );
    end else begin
        wait( `RING_RESET == rx1m_c_s[12:0] );
    end
    wait( ring_reset_pending );
    tx0m_c_s = 0;
    tx1m_c_s = 0;
    wait (( `eR_IDLE == tx0m_status ) && ( `eR_IDLE == tx1m_status ));
    wait ( master_node.rx0_clk_reset_cmd && master_node.rx1_clk_reset_cmd );
    display_results( 1 );
    #1000 // 1us
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "sr2cb_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // sr2cb_tb