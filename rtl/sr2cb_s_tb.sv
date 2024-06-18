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
 *  byte transfers initiated by a simulated master node (test bench).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

`include "sr2cb_def.v"

/*=============================================================================/
MASTER+  NODE8191+  NODE8190+                      NODE1---+  NODE0---+  MASTER+
| RX0 |<-| TX RX |<-| TX RX |<- - - - - - - - - -<-| TX RX |<-| TX RX |<-| TX0 |
|     |  NODE0 --+  NODE1 --+                      NODE8190+  NODE8191+  |     |
| TX1 |->| RX TX |->| RX TX |->- - - - - - - - - ->| RX TX |->| RX TX |->| RX1 |
------+  +-------+  +-------+                      +-------+  +-------+  ------+
/=============================================================================*/
module sr2cb_s_tb;
/*============================================================================*/
localparam NR_CHANNELS = 4;
localparam CHW = $clog2( NR_CHANNELS );

reg        clk;
reg        rst_n;
wire       rx0m_clk;
wire [7:0] rx0m_d;
wire       rx0m_dv;
wire       rx1m_clk;
wire [7:0] rx1m_d;
wire       rx1m_dv;
reg        tx0m_clk;
reg  [7:0] tx0m_d;
reg        tx0m_dv;
wire [7:0] phy_pre_0_d;
wire       phy_pre_0_dv;
wire       phy_pre_0_dr;
reg        tx1m_clk;
reg  [7:0] tx1m_d;
reg        tx1m_dv;
wire [7:0] phy_pre_1_d;
wire       phy_pre_1_dv;
wire       phy_pre_1_dr;
wire [7:0] tx0s0_d;
wire       tx0s0_dv;
wire       tx1s0_clk;
wire [7:0] tx1s0_d;
wire       tx1s0_dv;
wire       tx0s1_clk;
wire [7:0] tx0s1_d;
wire       tx0s1_dv;
wire       tx1s1_clk;
wire [7:0] tx1s1_d;
wire       tx1s1_dv;
wire       tx0s2_clk;
wire [7:0] tx0s2_d;
wire       tx0s2_dv;
wire [7:0] tx1s2_d;
wire       tx1s2_dv;
/*-------------------*/
wire [7:0] rx0s0_ch_d;
wire       rx0s0_ch_dv;
wire       rx0s0_ch_dr;
wire [7:0] tx0s0_ch_d;
wire [CHW-1:0] rx0s0_tx0_ch;
reg  [7:0] rx1s0_ch_d;
reg        rx1s0_ch_dv;
wire       rx1s0_ch_dr;
wire [7:0] tx1s0_ch_d;
wire [CHW-1:0] rx1s0_tx1_ch;
reg  [7:0] rx0s2_ch_d;
reg        rx0s2_ch_dv;
wire       rx0s2_ch_dr;
wire [7:0] tx0s2_ch_d;
wire [CHW-1:0] rx0s2_tx0_ch;
wire [7:0] rx1s2_ch_d;
wire       rx1s2_ch_dv;
wire       rx1s2_ch_dr;
wire [7:0] tx1s2_ch_d;
wire [CHW-1:0] rx1s2_tx1_ch;
/*---------------------------*/
reg   [7:0] rx0_d_count;
reg   [7:0] rx1_d_count;
wire [67:0] rx0s0_rt_clk_count;
wire [67:0] rx1s0_rt_clk_count;
wire [67:0] rx0s1_rt_clk_count;
wire [67:0] rx1s1_rt_clk_count;
wire [67:0] rx0s2_rt_clk_count;
wire [67:0] rx1s2_rt_clk_count;

/*============================================================================*/
sr2cb_m_phy_pre phy_pre_0(
/*============================================================================*/
    .clk(tx0m_clk),
    .rst_n(rst_n),
    .rx_d(tx0m_d),
    .rx_dv(tx0m_dv),
    .rx_dr(phy_pre_0_dr),
    .tx_d(phy_pre_0_d),
    .tx_dv(phy_pre_0_dv)
);

/*============================================================================*/
sr2cb_s slv_node_0(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0_clk(tx0m_clk),
    .rx0_d(tx0m_d_ii),
    .rx0_dv(tx0m_dv_ii),
    .rx0_err(1'b0),
    .tx0_clk(rx0m_clk),
    .tx0_d(tx0s0_d),
    .tx0_dv(tx0s0_dv),
    .tx0_dr(1'b1),
    .tx0_err(),
    .rx1_clk(tx0s1_clk),
    .rx1_d(tx0s1_d_i),
    .rx1_dv(tx0s1_dv_i),
    .rx1_err(1'b0),
    .tx1_clk(tx1s0_clk),
    .tx1_d(tx1s0_d),
    .tx1_dv(tx1s0_dv),
    .tx1_dr(1'b1),
    .tx1_err(),
    .rx0_ch_d(rx0s0_ch_d),
    .rx0_ch_dv(rx0s0_ch_dv),
    .rx0_ch_dr(rx0s0_ch_dr),
    .tx0_ch_d(tx0s0_ch_d),
    .rx0_tx0_ch(rx0s0_tx0_ch),
    .rx1_ch_d(rx1s0_ch_d),
    .rx1_ch_dv(rx1s0_ch_dv),
    .rx1_ch_dr(rx1s0_ch_dr),
    .tx1_ch_d(tx1s0_ch_d),
    .rx1_tx1_ch(rx1s0_tx1_ch),
    .rx0_rt_clk_count(rx0s0_rt_clk_count),
    .rx1_rt_clk_count(rx1s0_rt_clk_count)
);

defparam slv_node_0.NR_CHANNELS = NR_CHANNELS;

reg [7:0] tx0p_d;
reg       tx0p_dv;
reg [7:0] tx0m_d_i;
reg       tx0m_dv_i;
reg [7:0] tx0m_d_ii;
reg       tx0m_dv_ii;
/*============================================================================*/
always @( posedge tx0m_clk ) // Two clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx0p_d     <= 0;
    tx0p_dv    <= 0;
    tx0m_d_i   <= 0;
    tx0m_dv_i  <= 0;
    tx0m_d_ii  <= 0;
    tx0m_dv_ii <= 0;
    if ( rst_n ) begin // Extra clock cycle, tx0m_dv starts at negedge!
        tx0m_d_i   <= ( phy_pre_0_d & { 8{ phy_pre_0_dv }} ) | ( tx0p_d & { 8{ tx0p_dv }} );
        tx0m_dv_i  <= phy_pre_0_dv | tx0p_dv;
        tx0m_d_ii  <= tx0m_d_i;
        tx0m_dv_ii <= tx0m_dv_i;
    end
end

reg [7:0] tx0s0_d_i;
reg       tx0s0_dv_i;
/*============================================================================*/
always @( posedge rx0m_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx0s0_d_i  <= 0;
    tx0s0_dv_i <= 0;
    if ( rst_n ) begin
        tx0s0_d_i  <= tx0s0_d;
        tx0s0_dv_i <= tx0s0_dv;
    end
end
assign rx0m_d  = tx0s0_d_i;
assign rx0m_dv = tx0s0_dv_i;

reg [7:0] tx1s0_d_i;
reg       tx1s0_dv_i;
/*============================================================================*/
always @( posedge tx1s0_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx1s0_d_i  <= 0;
    tx1s0_dv_i <= 0;
    if ( rst_n ) begin
        tx1s0_d_i  <= tx1s0_d;
        tx1s0_dv_i <= tx1s0_dv;
    end
end

/*============================================================================*/
sr2cb_s slv_node_1(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0_clk(tx1s0_clk),
    .rx0_d(tx1s0_d_i),
    .rx0_dv(tx1s0_dv_i),
    .rx0_err(1'b0),
    .tx0_clk(tx0s1_clk),
    .tx0_d(tx0s1_d),
    .tx0_dv(tx0s1_dv),
    .tx0_dr(1'b1),
    .tx0_err(),
    .rx1_clk(tx0s2_clk),
    .rx1_d(tx0s2_d_i),
    .rx1_dv(tx0s2_dv_i),
    .rx1_err(1'b0),
    .tx1_clk(tx1s1_clk),
    .tx1_d(tx1s1_d),
    .tx1_dv(tx1s1_dv),
    .tx1_dr(1'b1),
    .tx1_err(),
    .rx0_ch_d(8'd0),
    .rx0_ch_dv(1'b0),
    .tx0_ch_d(),
    .rx0_tx0_ch(),
    .rx1_ch_d(8'd0),
    .rx1_ch_dv(1'b0),
    .tx1_ch_d(),
    .rx1_tx1_ch(),
    .rx0_rt_clk_count(rx0s1_rt_clk_count),
    .rx1_rt_clk_count(rx1s1_rt_clk_count)
);

defparam slv_node_1.NR_CHANNELS = NR_CHANNELS;

reg [7:0] tx0s1_d_i;
reg       tx0s1_dv_i;
/*============================================================================*/
always @( posedge tx0s1_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx0s1_d_i  <= 0;
    tx0s1_dv_i <= 0;
    if ( rst_n ) begin
        tx0s1_d_i  <= tx0s1_d;
        tx0s1_dv_i <= tx0s1_dv;
    end
end

reg [7:0] tx1s1_d_i;
reg       tx1s1_dv_i;
/*============================================================================*/
always @( posedge tx1s1_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx1s1_d_i  <= 0;
    tx1s1_dv_i <= 0;
    if ( rst_n ) begin
        tx1s1_d_i  <= tx1s1_d;
        tx1s1_dv_i <= tx1s1_dv;
    end
end

/*============================================================================*/
sr2cb_s slv_node_2(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0_clk(tx1s1_clk),
    .rx0_d(tx1s1_d_i),
    .rx0_dv(tx1s1_dv_i),
    .rx0_err(1'b0),
    .tx0_clk(tx0s2_clk),
    .tx0_d(tx0s2_d),
    .tx0_dv(tx0s2_dv),
    .tx0_dr(1'b1),
    .tx0_err(),
    .rx1_clk(tx1m_clk),
    .rx1_d(tx1m_d_ii),
    .rx1_dv(tx1m_dv_ii),
    .rx1_err(1'b0),
    .tx1_clk(rx1m_clk),
    .tx1_d(tx1s2_d),
    .tx1_dv(tx1s2_dv),
    .tx1_dr(1'b1),
    .tx1_err(),
    .rx0_ch_d(rx0s2_ch_d),
    .rx0_ch_dv(rx0s2_ch_dv),
    .rx0_ch_dr(rx0s2_ch_dr),
    .tx0_ch_d(tx0s2_ch_d),
    .rx0_tx0_ch(rx0s2_tx0_ch),
    .rx1_ch_d(rx1s2_ch_d),
    .rx1_ch_dv(rx1s2_ch_dv),
    .rx1_ch_dr(rx1s2_ch_dr),
    .tx1_ch_d(tx1s2_ch_d),
    .rx1_tx1_ch(rx1s2_tx1_ch),
    .rx0_rt_clk_count(rx0s2_rt_clk_count),
    .rx1_rt_clk_count(rx1s2_rt_clk_count)
);

defparam slv_node_2.NR_CHANNELS = NR_CHANNELS;

reg [7:0] tx0s2_d_i;
reg       tx0s2_dv_i;
/*============================================================================*/
always @( posedge tx0s2_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx0s2_d_i  <= 0;
    tx0s2_dv_i <= 0;
    if ( rst_n ) begin
        tx0s2_d_i  <= tx0s2_d;
        tx0s2_dv_i <= tx0s2_dv;
    end
end

reg [7:0] tx1p_d;
reg       tx1p_dv;
reg [7:0] tx1m_d_i;
reg       tx1m_dv_i;
reg [7:0] tx1m_d_ii;
reg       tx1m_dv_ii;
/*============================================================================*/
always @( posedge tx1m_clk ) // Two clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx1p_d     <= 0;
    tx1p_dv    <= 0;
    tx1m_d_i   <= 0;
    tx1m_dv_i  <= 0;
    tx1m_d_ii  <= 0;
    tx1m_dv_ii <= 0;
    if ( rst_n ) begin // Extra clock cycle, tx1m_dv starts at negedge!
        tx1m_d_i   <= ( phy_pre_1_d & { 8{ phy_pre_1_dv }} ) | ( tx1p_d & { 8{ tx1p_dv }} );
        tx1m_dv_i  <= phy_pre_1_dv | tx1p_dv;
        tx1m_d_ii  <= tx1m_d_i;
        tx1m_dv_ii <= tx1m_dv_i;
    end
end

/*============================================================================*/
sr2cb_m_phy_pre phy_pre_1(
/*============================================================================*/
    .clk(tx1m_clk),
    .rst_n(rst_n),
    .rx_d(tx1m_d),
    .rx_dv(tx1m_dv),
    .rx_dr(phy_pre_1_dr),
    .tx_d(phy_pre_1_d),
    .tx_dv(phy_pre_1_dv)
);

reg [7:0] tx1s2_d_i;
reg       tx1s2_dv_i;
/*============================================================================*/
always @( posedge rx1m_clk ) // One clock cycle interface RX signal delay
/*============================================================================*/
begin
    tx1s2_d_i  <= 0;
    tx1s2_dv_i <= 0;
    if ( rst_n ) begin
        tx1s2_d_i  <= tx1s2_d;
        tx1s2_dv_i <= tx1s2_dv;
    end
end
assign rx1m_d  = tx1s2_d_i;
assign rx1m_dv = tx1s2_dv_i;

initial begin
    tx0m_d_i   = 0;
    tx0m_dv_i  = 0;
    tx0s0_d_i  = 0;
    tx0s0_dv_i = 0;
    tx1s0_d_i  = 0;
    tx1s0_dv_i = 0;
    tx0s1_d_i  = 0;
    tx0s1_dv_i = 0;
    tx1s1_d_i  = 0;
    tx1s1_dv_i = 0;
    tx0s2_d_i  = 0;
    tx0s2_dv_i = 0;
    tx1s2_d_i  = 0;
    tx1s2_dv_i = 0;
    tx1m_d_i   = 0;
    tx1m_dv_i  = 0;
    /*------------*/
    rx1s0_ch_d  = 0;
    rx1s0_ch_dv = 0;
    rx0s2_ch_d  = 0;
    rx0s2_ch_dv = 0;
    rx0_d_count = 0;
    rx1_d_count = 0;
end

reg [12:0] node_pos[0:1];
reg [12:0] node_pos_rp[0:1]; // The node positions of returned packets

localparam CW_DIR  = 1'b0; // Ring clockwise direction
localparam CCW_DIR = 1'b1; // Ring counterclockwise direction

/*============================================================================*/
task send_r0_byte( input [7:0] byte_in, input set_parity );
/*============================================================================*/
begin
    wait ( tx0m_clk ) @( negedge tx0m_clk );
    tx0m_d[6:0] = byte_in[6:0];
    tx0m_d[7]   = set_parity ? ~( ^byte_in[6:0] ) : byte_in[7];
    tx0m_dv = 1;
end
endtask

/*============================================================================*/
task send_r1_byte( input [7:0] byte_in, input set_parity );
/*============================================================================*/
begin
    wait ( tx1m_clk ) @( negedge tx1m_clk );
    tx1m_d[6:0] = byte_in[6:0];
    tx1m_d[7]   = set_parity ? ~( ^byte_in[6:0] ) : byte_in[7];
    tx1m_dv = 1;
end
endtask

/*============================================================================*/
task send_r0_command( input [12:0] cmd );
/*============================================================================*/
begin
    wait ( phy_pre_0_dr );
    send_r0_byte( {1'b0, node_pos[0][6:0]}, 1 );
    send_r0_byte( {1'b0, CW_DIR, node_pos[0][12:7]}, 1 );
    send_r0_byte( {1'b0, cmd[6:0]}, 1 );
    send_r0_byte( {1'b0, 1'b1, cmd[12:7]}, 1 ); // Set command bit
end
endtask

/*============================================================================*/
task send_r1_command( input [12:0] cmd );
/*============================================================================*/
begin
    wait ( phy_pre_1_dr );
    send_r1_byte( {1'b0, node_pos[1][6:0]}, 1 );
    send_r1_byte( {1'b0, CCW_DIR, node_pos[1][12:7]}, 1 );
    send_r1_byte( {1'b0, cmd[6:0]}, 1 );
    send_r1_byte( {1'b0, 1'b1, cmd[12:7]}, 1 ); // Set command bit
end
endtask

/*============================================================================*/
task send_r0_status( input [12:0] status );
/*============================================================================*/
begin
    wait ( phy_pre_0_dr );
    send_r0_byte( {1'b0, node_pos[0][6:0]}, 1 );
    send_r0_byte( {1'b0, CW_DIR, node_pos[0][12:7]}, 1 );
    send_r0_byte( {1'b0, status[6:0]}, 1 );
    send_r0_byte( {1'b0, 1'b0, status[12:7]}, 1 ); // Reset status bit
end
endtask

/*============================================================================*/
task send_r1_status( input [12:0] status );
/*============================================================================*/
begin
    wait ( phy_pre_1_dr );
    send_r1_byte( {1'b0, node_pos[1][6:0]}, 1 );
    send_r1_byte( {1'b0, CCW_DIR, node_pos[1][12:7]}, 1 );
    send_r1_byte( {1'b0, status[6:0]}, 1 );
    send_r1_byte( {1'b0, 1'b0, status[12:7]}, 1 ); // Reset status bit
end
endtask

reg [27:0] delay_m[0:1]; // Delay measured by master node
reg [10:0] delay_count;
reg        delay_count_en;
reg [27:0] delay[0:2][0:1]; // Delay received from all nodes
reg        wait_for_rx0m_dv;
reg        wait_for_rx1m_dv;
reg [63:0] master_clk_count;

integer k;
/*============================================================================*/
task send_r0_delay;
/*============================================================================*/
begin
    send_r0_byte( {1'b0, delay_m[0][6:0]}, 1 );
    send_r0_byte( {1'b0, delay_m[0][13:7]}, 1 );
    send_r0_byte( {1'b0, delay_m[0][20:14]}, 1 );
    send_r0_byte( {1'b0, delay_m[0][27:21]}, 1 );
    wait ( tx0m_clk ) @( negedge tx0m_clk );
    tx0m_dv = 0;
    wait ( tx0m_clk ) @( negedge tx0m_clk );
    wait ( ~rx0m_dv ); // Wait for received message has ended!
    wait ( tx0m_clk ) @( negedge tx0m_clk );
    // Wait for rx0m_dv high with time-out
    for ( k = 0; (( k < 1000 ) && wait_for_rx0m_dv ); k = k + 1 ) begin
        #1; // 1ns
    end
    if ( wait_for_rx0m_dv ) begin
        $display( "No messages received from R0 node" );
        $finish;
    end
end
endtask

/*============================================================================*/
task send_r1_delay;
/*============================================================================*/
begin
    send_r1_byte( {1'b0, delay_m[1][6:0]}, 1 );
    send_r1_byte( {1'b0, delay_m[1][13:7]}, 1 );
    send_r1_byte( {1'b0, delay_m[1][20:14]}, 1 );
    send_r1_byte( {1'b0, delay_m[1][27:21]}, 1 );
    wait ( tx1m_clk ) @( negedge tx1m_clk );
    tx1m_dv = 0;
    wait ( tx1m_clk ) @( negedge tx1m_clk );
    wait ( ~rx1m_dv ); // Wait for received message has ended!
    wait ( tx1m_clk ) @( negedge tx1m_clk );
    // Wait for rx10m_dv high with time-out
    for ( k = 0; (( k < 1000 ) && wait_for_rx1m_dv ); k = k + 1 ) begin
        #1; // 1ns
    end
    if ( wait_for_rx1m_dv ) begin
        $display( "No messages received from R1 node" );
        $finish;
    end
end
endtask

/*============================================================================*/
task send_r0_clock_sync( input [12:0] cmd );
/*============================================================================*/
begin
    rx0_status   = `eR_INIT;
    rx1_status   = `eR_IDLE;
    rx0_loopback = 0;
    rx1_loopback = 1;
    if (( cmd & 13'h1FFC ) != `CLK_SYNC_0 ) begin
        $display( "Incorrect clock sync command!" );
        $stop;
    end
    node_pos[0] = 0;
    delay_count = 0;
    repeat ( 1 << cmd[1:0]) begin
        send_r0_command( cmd );
        send_r0_delay;
        wait ( ~rx0m_dv ); // Wait for received message has ended!
        wait ( tx0m_clk ) @( negedge tx0m_clk );
    end
    if ( !delay_m[0] ) begin
        delay_m[0] = { {9{1'b0}},  {{delay_count, 4'h0} >> ( cmd[1:0] + 1 ) }};
    end
    cmd = cmd | 13'h4; // Set delay valid bit "_SET"
    send_r0_command( cmd );
    send_r0_delay;
    wait ( ~rx0m_dv ); // Wait for received message has ended!
    wait ( tx0m_clk ) @( negedge tx0m_clk );
end
endtask

/*============================================================================*/
task send_r1_clock_sync( input [12:0] cmd );
/*============================================================================*/
begin
    rx0_status   = `eR_IDLE;
    rx1_status   = `eR_INIT;
    rx0_loopback = 1;
    rx1_loopback = 0;
    if (( cmd & 13'h1FFC ) != `CLK_SYNC_0 ) begin
        $display( "Incorrect clock sync command!" );
        $stop;
    end
    node_pos[1] = 0;
    delay_count = 0;
    repeat ( 1 << cmd[1:0]) begin
        send_r1_command( cmd );
        send_r1_delay;
        wait ( ~rx1m_dv ); // Wait for received message has ended!
        wait ( tx1m_clk ) @( negedge tx1m_clk );
    end
    if ( !delay_m[1] ) begin
        delay_m[1] = { {9{1'b0}},  {{delay_count, 4'h0} >> ( cmd[1:0] + 1 ) }};
    end
    cmd = cmd | 13'h4; // Set delay valid bit "_SET"
    send_r1_command( cmd );
    send_r1_delay;
    wait ( ~rx1m_dv ); // Wait for received message has ended!
    wait ( tx1m_clk ) @( negedge tx1m_clk );
end
endtask

integer m;
/*============================================================================*/
task send_r0_packet( input [13:0] c_s );
/*============================================================================*/
begin
    wait ( phy_pre_0_dr );
    if ( c_s[13] ) begin
        send_r0_command( c_s[12:0] );
    end
    else begin
        if ( 0 == c_s[12:10] ) begin // Send master clock status
            send_r0_status( {3'd0, master_clk_count[9:0]} );
        end
        else begin
            send_r0_status( c_s[12:0] );
        end
    end
    for ( m = 0; m < NR_CHANNELS; m = m + 1 ) begin
        send_r0_byte( 0, 0 );
    end
    wait ( tx0m_clk ) @( negedge tx0m_clk );
    tx0m_dv = 0;
    wait ( tx0m_clk ) @( negedge tx0m_clk );
end
endtask

integer n;
/*============================================================================*/
task send_r1_packet( input [13:0] c_s );
/*============================================================================*/
begin
    wait ( phy_pre_1_dr );
    if ( c_s[13] ) begin
        send_r1_command( c_s[12:0] );
    end
    else begin
        if ( 0 == c_s[12:10] ) begin // Send master clock status
            send_r1_status( {3'd0, master_clk_count[9:0]} );
        end
        else begin
            send_r1_status( c_s[12:0] );
        end
    end
    for ( n = 0; n < NR_CHANNELS; n = n + 1 ) begin
        send_r1_byte( 0, 0 );
    end
    wait ( tx1m_clk ) @( negedge tx1m_clk );
    tx1m_dv = 0;
    wait ( tx1m_clk ) @( negedge tx1m_clk );
end
endtask


localparam NODE_POS_OFFSET = 8; // PREAMBLE_SFD for phy_pre_0/1

reg [7:0]  rx0_d_c;
reg [1:0]  rx0_dv_i;
reg [2:0]  rx0_status;
reg [13:0] rx0_c_s;
reg [3:0]  rx0_nb_bytes;
reg [5:0]  rx0_nb_samples;
reg        rx0_loopback;
wire       rx0_nb_samples_c;
wire       rx0_clk_sync_c_s;
wire       rx0_clk_sync_cmd;
wire       rx0_clk_sync_st;
wire       rx0_clk_sync_set_cmd;
assign rx0_nb_samples_c = ( 2 << ( rx0_c_s & 13'h3 )) == rx0_nb_samples;
assign rx0_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == rx0_c_s[12:3];
assign rx0_clk_sync_cmd = rx0_clk_sync_c_s & rx0_c_s[13];
assign rx0_clk_sync_st = rx0_clk_sync_c_s & !rx0_c_s[13] & !rx0_c_s[2];
assign rx0_clk_sync_set_cmd = rx0_clk_sync_c_s & rx0_c_s[13] & rx0_c_s[2];
assign rx0s0_ch_dv = rx0s0_ch_dr && ( 0 == rx0s0_tx0_ch );
assign rx0s0_ch_d = rx0_d_count;

/*============================================================================*/
always @( posedge rx0m_clk ) begin : rx0_process
/*============================================================================*/
    tx0p_d  <= 0;
    tx0p_dv <= 0;
    if (( `eR_IDLE == rx0_status ) && rx0_loopback ) begin
        tx0p_d  <= rx0m_d;
        tx0p_dv <= rx0m_dv;
    end

    rx0_dv_i <= { rx0_dv_i[0], rx0m_dv };

    if ( rx0m_dv ) begin
        if ( NODE_POS_OFFSET == rx0_nb_bytes ) begin
            node_pos_rp[0][6:0] <= rx0m_d[6:0];
            if ( `eR_IDLE == rx0_status ) begin
                tx0p_d[6:0] <= 0; // Set node position to zero
                tx0p_d[7]   <= 1;
            end
        end
        if (( NODE_POS_OFFSET + 1 ) == rx0_nb_bytes ) begin
            node_pos_rp[0][12:7] <= rx0m_d[5:0];
            if ( `eR_IDLE == rx0_status ) begin
                tx0p_d[6:0] <= 0; // Set node position to zero
                tx0p_d[7]   <= 1;
            end
        end
        if (( NODE_POS_OFFSET + 2 ) == rx0_nb_bytes ) begin
            rx0_c_s[6:0] <= rx0m_d[6:0];
            if ( `eR_IDLE == rx0_status ) begin
                if (( `CLK_SYNC_SET_0 >> 2 ) == rx0m_d[6:2] ) begin // Check for CLK_SYNC_SET cmd
                    tx0p_d[6:0] <= 0; // Reset command
                    tx0p_d[7]   <= 1;
                end
            end
        end
        if (( NODE_POS_OFFSET + 3 ) == rx0_nb_bytes ) begin
            rx0_c_s[13:7] <= rx0m_d[6:0];
            rx0_d_c = { rx0m_d[7], 1'b0, rx0m_d[5:0] };
            if ( `eR_IDLE == rx0_status ) begin
                tx0p_d[6:0] <= rx0_d_c; // Reset command bit
                tx0p_d[7]   <= ~( ^rx0_d_c ); // Set even partity
                if ( !tx0p_d[6:0] ) begin // Check for reset cmd
                    tx0p_d[5:0] <= 0;     // Reset command
                    tx0p_d[7:6] <= 2'b01; // Set command bit + parity
                end
            end
        end
        if (( NODE_POS_OFFSET + 4 ) == rx0_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx0_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[0] ) begin
                    delay[0][0][6:0] <= rx0m_d[6:0];
                end
                if ( 1 == node_pos_rp[0] ) begin
                    delay[1][0][6:0] <= rx0m_d[6:0];
                end
                if ( 2 == node_pos_rp[0] ) begin
                    delay[2][0][6:0] <= rx0m_d[6:0];
                end
            end
            if ( !rx0_nb_samples_c ) begin
                rx0_nb_samples <= rx0_nb_samples + 1;
            end
        end
        if (( NODE_POS_OFFSET + 5 ) == rx0_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx0_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[0] ) begin
                    delay[0][0][13:7] <= rx0m_d[6:0];
                end
                if ( 1 == node_pos_rp[0] ) begin
                    delay[1][0][13:7] <= rx0m_d[6:0];
                end
                if ( 2 == node_pos_rp[0] ) begin
                    delay[2][0][13:7] <= rx0m_d[6:0];
                end
            end
        end
        if (( NODE_POS_OFFSET + 6 ) == rx0_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx0_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[0] ) begin
                    delay[0][0][20:14] <= rx0m_d[6:0];
                end
                if ( 1 == node_pos_rp[0] ) begin
                    delay[1][0][20:14] <= rx0m_d[6:0];
                end
                if ( 2 == node_pos_rp[0] ) begin
                    delay[2][0][20:14] <= rx0m_d[6:0];
                end
            end
        end
        if (( NODE_POS_OFFSET + 7 ) == rx0_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx0_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[0] ) begin
                    delay[0][0][27:21] <= rx0m_d[6:0];
                end
                if ( 1 == node_pos_rp[0] ) begin
                    delay[1][0][27:21] <= rx0m_d[6:0];
                end
                if ( 2 == node_pos_rp[0] ) begin
                    delay[2][0][27:21] <= rx0m_d[6:0];
                end
            end
        end
        rx0_nb_bytes = rx0_nb_bytes + 1;
    end
    else begin
        rx0_nb_bytes = 0;
        if (( `CLK_SYNC_SET_0 >> 2 ) == rx0_c_s[12:2] ) begin
            if ( rx0_nb_samples_c ) begin
                rx0_nb_samples <= 0;
            end
        end
    end

    if ( rx0s0_ch_dv ) begin
        rx0_d_count <= rx0_d_count + 1;
    end
end

reg [7:0]  rx1_d_c;
reg [1:0]  rx1_dv_i;
reg [2:0]  rx1_status;
reg [13:0] rx1_c_s;
reg [3:0]  rx1_nb_bytes;
reg [5:0]  rx1_nb_samples;
reg        rx1_loopback;
wire       rx1_nb_samples_c;
wire       rx1_clk_sync_c_s;
wire       rx1_clk_sync_cmd;
wire       rx1_clk_sync_st;
wire       rx1_clk_sync_set_cmd;
assign rx1_nb_samples_c = ( 2 << ( rx1_c_s & 13'h3 )) == rx1_nb_samples;
assign rx1_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == rx1_c_s[12:3];
assign rx1_clk_sync_cmd = rx1_clk_sync_c_s && rx1_c_s[13];
assign rx1_clk_sync_st = rx1_clk_sync_c_s && !rx1_c_s[13] && !rx1_c_s[2];
assign rx1_clk_sync_set_cmd = rx1_clk_sync_c_s && rx1_c_s[13] && rx1_c_s[2];
assign rx1s2_ch_dv = rx1s2_ch_dr && ( 3 == rx1s2_tx1_ch );
assign rx1s2_ch_d = rx1_d_count;

/*============================================================================*/
always @( posedge rx1m_clk ) begin : rx1_process
/*============================================================================*/
    tx1p_d  <= 0;
    tx1p_dv <= 0;
    if (( `eR_IDLE == rx1_status ) && rx1_loopback ) begin
        tx1p_d  <= rx1m_d;
        tx1p_dv <= rx1m_dv;
    end

    rx1_dv_i <= { rx1_dv_i[0], rx1m_dv };

    if ( rx1m_dv ) begin
        if ( NODE_POS_OFFSET == rx1_nb_bytes ) begin
            node_pos_rp[1][6:0] <= rx1m_d[6:0];
            if ( `eR_IDLE == rx1_status ) begin
                tx1p_d[6:0] <= 0; // Set node position to zero
                tx1p_d[7]   <= 1;
            end
        end
        if (( NODE_POS_OFFSET + 1 ) == rx1_nb_bytes ) begin
            node_pos_rp[1][12:7] <= rx1m_d[5:0];
            if ( `eR_IDLE == rx1_status ) begin
                tx1p_d[6:0] <= 0; // Set node position to zero
                tx1p_d[7]   <= 1;
            end
        end
        if (( NODE_POS_OFFSET + 2 ) == rx1_nb_bytes ) begin
            rx1_c_s[6:0] <= rx1m_d[6:0];
            if ( `eR_IDLE == rx1_status ) begin
                if (( `CLK_SYNC_SET_0 >> 2 ) == rx1m_d[6:2] ) begin // Check for CLK_SYNC_SET cmd
                    tx1p_d[6:0] <= 0; // Reset command
                    tx1p_d[7]   <= 1;
                end
            end
        end
        if (( NODE_POS_OFFSET + 3 ) == rx1_nb_bytes ) begin
            rx1_c_s[13:7] <= rx1m_d[6:0];
            rx1_d_c = { rx1m_d[7], 1'b0, rx1m_d[5:0] };
            if ( `eR_IDLE == rx1_status ) begin
                tx1p_d[6:0] <= rx1_d_c; // Reset command bit
                tx1p_d[7]   <= ~( ^rx1_d_c ); // Set even partity
                if ( !tx1p_d[6:0] ) begin // Check for reset cmd
                    tx1p_d[5:0] <= 0;     // Reset command
                    tx1p_d[7:6] <= 2'b01; // Set command bit + parity
                end
            end
        end
        if (( NODE_POS_OFFSET + 4 ) == rx1_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx1_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[1] ) begin
                    delay[0][1][6:0] <= rx1m_d[6:0];
                end
                if ( 1 == node_pos_rp[1] ) begin
                    delay[1][1][6:0] <= rx1m_d[6:0];
                end
                if ( 2 == node_pos_rp[1] ) begin
                    delay[2][1][6:0] <= rx1m_d[6:0];
                end
            end
            if ( !rx1_nb_samples_c ) begin
                rx1_nb_samples <= rx1_nb_samples + 1;
            end
        end
        if (( NODE_POS_OFFSET + 5 ) == rx1_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx1_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[1] ) begin
                    delay[0][1][13:7] <= rx1m_d[6:0];
                end
                if ( 1 == node_pos_rp[1] ) begin
                    delay[1][1][13:7] <= rx1m_d[6:0];
                end
                if ( 2 == node_pos_rp[1] ) begin
                    delay[2][1][13:7] <= rx1m_d[6:0];
                end
            end
        end
        if (( NODE_POS_OFFSET + 6 ) == rx1_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx1_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[1] ) begin
                    delay[0][1][20:14] <= rx1m_d[6:0];
                end
                if ( 1 == node_pos_rp[1] ) begin
                    delay[1][1][20:14] <= rx1m_d[6:0];
                end
                if ( 2 == node_pos_rp[1] ) begin
                    delay[2][1][20:14] <= rx1m_d[6:0];
                end
            end
        end
        if (( NODE_POS_OFFSET + 7 ) == rx1_nb_bytes ) begin
            if (( `CLK_SYNC_SET_0 >> 2 ) == rx1_c_s[12:2] ) begin
                if ( 0 == node_pos_rp[1] ) begin
                    delay[0][1][27:21] <= rx1m_d[6:0];
                end
                if ( 1 == node_pos_rp[1] ) begin
                    delay[1][1][27:21] <= rx1m_d[6:0];
                end
                if ( 2 == node_pos_rp[1] ) begin
                    delay[2][1][27:21] <= rx1m_d[6:0];
                end
            end
        end
        rx1_nb_bytes = rx1_nb_bytes + 1;
    end
    else begin
        rx1_nb_bytes = 0;
        if (( `CLK_SYNC_SET_0 >> 2 ) == rx1_c_s[12:2] ) begin
            if ( rx1_nb_samples_c ) begin
                rx1_nb_samples <= 0;
            end
        end
    end

    if ( rx1s2_ch_dv ) begin
        rx1_d_count <= rx1_d_count + 1;
    end
end

reg [1:0]  rx0m_clk_i;
reg [1:0]  rx1m_clk_i;
reg [1:0]  tx0m_clk_i;
reg [1:0]  tx1m_clk_i;
reg [12:0] rx0_nb_bytes_i;
reg [12:0] rx1_nb_bytes_i;
/*----------------------*/
reg rx0m_dv_posedge;
reg tx0m_dv_posedge;
reg rx1m_dv_posedge;
reg tx1m_dv_posedge;
/*============================================================================*/
initial begin
/*============================================================================*/
    rx0m_clk_i = 0;
    rx1m_clk_i = 0;
    tx0m_clk_i = 0;
    tx1m_clk_i = 0;
    rx0_dv_i   = 0;
    rx1_dv_i   = 0;
    /*----------------*/
    rx0_nb_bytes_i  = 0;
    rx1_nb_bytes_i  = 0;
    rx0m_dv_posedge = 0;
    tx0m_dv_posedge = 0;
    rx1m_dv_posedge = 0;
    tx1m_dv_posedge = 0;
    /*-----------------*/
    delay_count      = 0;
    delay_count_en   = 0;
    wait_for_rx0m_dv = 0;
    wait_for_rx1m_dv = 0;
    /*------------------*/
    master_clk_count = 0;
end

/*============================================================================*/
always @( posedge clk ) begin : handle_ports
/*============================================================================*/
    rx0m_clk_i <= { rx0m_clk_i[0], rx0m_clk };
    rx1m_clk_i <= { rx1m_clk_i[0], rx1m_clk };
    tx0m_clk_i <= { tx0m_clk_i[0], tx0m_clk };
    tx1m_clk_i <= { tx1m_clk_i[0], tx1m_clk };

    rx0_nb_bytes_i <= rx0_nb_bytes;
    rx1_nb_bytes_i <= rx1_nb_bytes;

    rx0m_dv_posedge <= ( 2'b01 == rx0m_clk_i ) && rx0m_dv;
    tx0m_dv_posedge <= ( 2'b01 == tx0m_clk_i ) && tx0m_dv;
    rx1m_dv_posedge <= ( 2'b01 == rx1m_clk_i ) && rx1m_dv;
    tx1m_dv_posedge <= ( 2'b01 == tx1m_clk_i ) && tx1m_dv;

    if ( `eR_INIT == rx0_status ) begin
        if ( tx0m_dv_posedge && !rx0m_dv ) begin
            delay_count_en <= !delay_m[0]; // Start counting when delay has not been set yet
        end

        if ( rx0m_dv_posedge ) begin
            delay_count_en <= 0;
        end
    end

    if ( tx0m_dv && !tx0m_dv_i ) begin
        wait_for_rx0m_dv <= 1;
    end

    if ( rx0m_dv_posedge ) begin
        wait_for_rx0m_dv <= 0;
    end

    if ( `eR_INIT == rx1_status ) begin
        if ( tx1m_dv_posedge && !rx1m_dv ) begin
            delay_count_en <= !delay_m[1]; // Start counting when delay has not been set yet
        end

        if ( rx1m_dv_posedge ) begin
            delay_count_en <= 0;
        end
    end

    if ( tx1m_dv && !tx1m_dv_i ) begin
        wait_for_rx1m_dv <= 1;
    end

    if ( rx1m_dv_posedge ) begin
        wait_for_rx1m_dv <= 0;
    end

    if ( delay_count_en ) begin
        delay_count <= delay_count + 1;
    end

    master_clk_count <= master_clk_count + 1;
end

always #5  clk = ~clk; // 100 MHz clock
always #40 tx0m_clk = ~tx0m_clk; // 12.5 MHz clock
always #40 tx1m_clk = ~tx1m_clk; // 12.5 MHz clock

localparam [12:0] CLK_SYNC_CMD = `CLK_SYNC_0; // Select *_0, *_1, *_2 or *_3!
localparam [12:0] CLK_SYNC_CMD_SET = CLK_SYNC_CMD | 13'h4;

reg passed;
integer i;
integer j;
/*============================================================================*/
task ring_init;
/*============================================================================*/
begin
    send_r0_clock_sync( CLK_SYNC_CMD );
    // Resend CLK_SYNC_SET_0 command, wait for delay[2][0] set!
    for ( i = 0; (( i < 10 ) && !delay[2][0] ); i = i + 1 ) begin
        send_r0_command( CLK_SYNC_CMD_SET );
        send_r0_delay;
    end
    rx0_status = `eR_IDLE;

    $display( "delay[0][0] = %0d, slv_node_0 rx0_status = %0d", delay[0][0], slv_node_0.rx0_status );
    $display( "delay[1][0] = %0d, slv_node_1 rx0_status = %0d", delay[1][0], slv_node_1.rx0_status );
    $display( "delay[2][0] = %0d, slv_node_2 rx0_status = %0d", delay[2][0], slv_node_2.rx0_status );
    passed = ( 192 == delay[0][0] ) && ( 384 == delay[1][0] ) && ( 576 == delay[2][0] ) &&
        ( 3 == slv_node_0.rx0_status) && ( 3 == slv_node_1.rx0_status) && ( 3 == slv_node_2.rx0_status);
    $display( "Initialization R0 %s", ( passed ? "passed" : "failed" ));

    if ( !delay[2][0] ) begin
        $display( "No delay[2][0] value received via R0 node" );
        $finish;
    end

    // Flush all messages from ring!
    for ( i = 0; ( i < delay[2][0] ); i = i + 1 ) begin
        #5; // 5ns
    end

    wait ( !rx1_dv_i );

    send_r1_clock_sync( CLK_SYNC_CMD );
    // Resend CLK_SYNC_SET_0 command, wait for delay[2][1] set!
    for ( i = 0; (( i < 10 ) && !delay[2][1] ); i = i + 1 ) begin
        send_r1_command( CLK_SYNC_CMD_SET );
        send_r1_delay;
    end

    wait ( !rx0_dv_i );

    rx0_loopback = 0;
    rx1_loopback = 0;
    rx1_status   = `eR_IDLE;

    #1000;
    $display( "" );
    $display( "delay[2][1] = %0d, slv_node_0 rx0_status = %0d rx1_status = %0d", delay[2][1], slv_node_0.rx0_status, slv_node_0.rx1_status );
    $display( "delay[1][1] = %0d, slv_node_1 rx0_status = %0d rx1_status = %0d", delay[1][1], slv_node_1.rx0_status, slv_node_1.rx1_status );
    $display( "delay[0][1] = %0d, slv_node_2 rx0_status = %0d rx1_status = %0d", delay[0][1], slv_node_2.rx0_status, slv_node_2.rx1_status );
    passed = ( 192 == delay[0][1] ) && ( 384 == delay[1][1] ) && ( 576 == delay[2][1] ) &&
        ( 4 == slv_node_0.rx0_status) && ( 4 == slv_node_1.rx0_status) && ( 4 == slv_node_2.rx0_status) &&
        ( 4 == slv_node_0.rx1_status) && ( 4 == slv_node_1.rx1_status) && ( 4 == slv_node_2.rx1_status);
    $display( "Initialization R0 and R1 %s", ( passed ? "passed" : "failed" ));
    $display( "" );

    if ( !delay[2][1] ) begin
        $display( "No delay[2][1] value received via R1 node" );
        $finish;
    end

    $display( "Master, clock R0/R1 = %0d before clock reset", master_clk_count );
    $display( "Slave node 0, clock R0 = %0d, clock R1 = %0d", slv_node_0.rx0_clk_count[67:4], slv_node_0.rx1_clk_count[67:4] );
    $display( "Slave node 1, clock R0 = %0d, clock R1 = %0d", slv_node_1.rx0_clk_count[67:4], slv_node_1.rx1_clk_count[67:4] );
    $display( "Slave node 2, clock R0 = %0d, clock R1 = %0d", slv_node_2.rx0_clk_count[67:4], slv_node_2.rx1_clk_count[67:4] );
    $display( "" );

    master_clk_count = 0;
    fork // Parallel operation
        send_r0_packet( {1'b1, `CLK_RESET} );
        send_r1_packet( {1'b1, `CLK_RESET} );
    join
    wait ( rx0m_dv );
    wait ( rx1m_dv );
    #1000; // 1us

    $display( "M/S clocks reset, set slave nodes rx0/rx1 clocks with -200ns!" );
    slv_node_0.rx0_clk_count = ( slv_node_0.rx0_m_clk - 20 ) * 16;
    slv_node_1.rx0_clk_count = ( slv_node_1.rx0_m_clk - 20 ) * 16;
    slv_node_2.rx0_clk_count = ( slv_node_2.rx0_m_clk - 20 ) * 16;
    slv_node_0.rx1_clk_count = ( slv_node_0.rx1_m_clk - 20 ) * 16;
    slv_node_1.rx1_clk_count = ( slv_node_1.rx1_m_clk - 20 ) * 16;
    slv_node_2.rx1_clk_count = ( slv_node_2.rx1_m_clk - 20 ) * 16;
    $display( "Slave node 0, clock R0 = %0d, M0 = %0d, clock R1 = %0d, M1 = %0d",
        slv_node_0.rx0_clk_count[67:4], slv_node_0.rx0_m_clk, slv_node_0.rx1_clk_count[67:4], slv_node_0.rx1_m_clk );
    $display( "Slave node 1, clock R0 = %0d, M0 = %0d, clock R1 = %0d, M1 = %0d",
        slv_node_1.rx0_clk_count[67:4], slv_node_1.rx0_m_clk, slv_node_1.rx1_clk_count[67:4], slv_node_1.rx1_m_clk );
    $display( "Slave node 2, clock R0 = %0d, M0 = %0d, clock R1 = %0d, M1 = %0d",
        slv_node_2.rx0_clk_count[67:4], slv_node_2.rx0_m_clk, slv_node_2.rx1_clk_count[67:4], slv_node_2.rx1_m_clk );
    $display( "" );

    passed = 0;
    for ( i = 0; (( i < 200 ) && !passed ); i = i + 1 ) begin
    fork // Parallel operation
        send_r0_packet( 13'd0 ); // Master clock status
        send_r1_packet( 13'd0 );
    join
        passed =
            ( slv_node_0.rx0_clk_count[67:4] == slv_node_0.rx0_m_clk ) &&
            ( slv_node_0.rx1_clk_count[67:4] == slv_node_0.rx1_m_clk ) &&
            ( slv_node_1.rx0_clk_count[67:4] == slv_node_1.rx0_m_clk ) &&
            ( slv_node_1.rx1_clk_count[67:4] == slv_node_1.rx1_m_clk ) &&
            ( slv_node_2.rx0_clk_count[67:4] == slv_node_2.rx0_m_clk ) &&
            ( slv_node_2.rx1_clk_count[67:4] == slv_node_2.rx1_m_clk );
    end

    $display( "Slave node 0, clock R0 = %0d -> %0d, clock R1 = %0d -> %0d", slv_node_0.rx0_clk_count[67:4], slv_node_0.rx0_m_clk,
        slv_node_0.rx1_clk_count[67:4], slv_node_0.rx1_m_clk );
    $display( "Slave node 1, clock R0 = %0d -> %0d, clock R1 = %0d -> %0d", slv_node_1.rx0_clk_count[67:4], slv_node_1.rx0_m_clk,
        slv_node_1.rx1_clk_count[67:4], slv_node_1.rx1_m_clk );
    $display( "Slave node 2, clock R0 = %0d -> %0d, clock R1 = %0d -> %0d", slv_node_2.rx0_clk_count[67:4], slv_node_2.rx0_m_clk,
        slv_node_2.rx1_clk_count[67:4], slv_node_2.rx1_m_clk );
    $display( "Clock synchronization R0 and R1 %s", ( passed ? "passed" : "failed" ));
    $display( "" );

    $display( "Master, clock R0/R1 = %0d", master_clk_count );
    $display( "Slave node 0, RT clock R0 = %0d.%0d, RT clock R1 = %0d.%0d", rx0s0_rt_clk_count[67:4], rx0s0_rt_clk_count[3:0],
        rx1s0_rt_clk_count[67:4], rx1s0_rt_clk_count[3:0] );
    $display( "Slave node 1, RT clock R0 = %0d.%0d, RT clock R1 = %0d.%0d", rx0s1_rt_clk_count[67:4], rx0s1_rt_clk_count[3:0],
        rx1s1_rt_clk_count[67:4], rx1s1_rt_clk_count[3:0] );
    $display( "Slave node 2, RT clock R0 = %0d.%0d, RT clock R1 = %0d.%0d", rx0s2_rt_clk_count[67:4], rx0s2_rt_clk_count[3:0],
        rx1s2_rt_clk_count[67:4], rx1s2_rt_clk_count[3:0] );
    $display( "" );
end
endtask

/*============================================================================*/
initial begin // Test bench
/*============================================================================*/
    rst_n    = 0;
    clk      = 0;
    passed   = 0;
    tx0m_clk = 0;
    tx0m_d   = 0;
    tx0m_dv  = 0;
    tx0p_d   = 0;
    tx0p_dv  = 0;
    tx1m_clk = 0;
    tx1m_d   = 0;
    tx1m_dv  = 0;
    tx1p_d   = 0;
    tx1p_dv  = 0;
    /*---------*/
    rx0_status     = `eR_IDLE;
    rx0_c_s        = 0;
    rx0_nb_bytes   = 0;
    rx0_nb_samples = 0;
    rx0_loopback   = 0;
    rx1_status     = `eR_IDLE;
    rx1_c_s        = 0;
    rx1_nb_bytes   = 0;
    rx1_nb_samples = 0;
    rx1_loopback   = 0;
    /*---------*/
    for ( j = 0; j < 3; j = j + 1 ) begin
        for ( i = 0; i < 2; i = i + 1 ) delay[j][i] = 0;
    end
    for ( i = 0; i < 2; i = i + 1 ) begin
        delay_m[i]        = 0;
        node_pos[i]       = 0;
        node_pos_rp[i]    = 0;
    end
    $display( "SR2CB slave simulation started" );
    #100    // 100ns
    rst_n = 1;
    #100    // 100ns
    ring_init;
    #10000  // 10us
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "sr2cb_s_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule