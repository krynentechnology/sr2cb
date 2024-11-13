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
 *  Description: SR2CB master node implementation.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
`include "sr2cb_def.v"

/*============================================================================*/
module sr2cb_m #(
/*============================================================================*/
    parameter NR_CHANNELS = 608,
    parameter [0:0] PREAMBLE_SFD = 1 )
    (
    clk, rst_n,
    rx0tx0_link, rx0_loopback,
    rx0_clk, rx0_d, rx0_dv, rx0_err, // _d = data, _dv = data valid
    tx0_clk, tx0_d, tx0_dv, tx0_dr, tx0_err, // _dr = data ready
    rx1tx1_link, rx1_loopback,
    rx1_clk, rx1_d, rx1_dv, rx1_err,
    tx1_clk, tx1_d, tx1_dv, tx1_dr, tx1_err,
    rx0_ch_d, rx0_ch_dv, rx0_ch_dr, tx0_ch_d, rx0_tx0_ch, // _ch = channel
    rx1_ch_d, rx1_ch_dv, rx1_ch_dr, tx1_ch_d, rx1_tx1_ch,
    rx0_node_pos, rx0_c_s, // _c_s = command/status
    rx1_node_pos, rx1_c_s,
    rx0_status, rx0_delay,
    rx1_status, rx1_delay,
    tx0_status, tx0_c_s,
    tx1_status, tx1_c_s,
    tx0rx0_valid,
    tx1rx1_valid,
    ring_reset_pending,
    clk_count
    );

localparam MAX_CLOG2_WIDTH = 16;
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

localparam NODE_POS_OFFSET = PREAMBLE_SFD * 8;
localparam CHANNEL_OFFSET  = NODE_POS_OFFSET + 4;
localparam CHW = clog2( NR_CHANNELS ); // Channel width
localparam NRBW = clog2( NR_CHANNELS + CHANNEL_OFFSET ); // RX bytes counter width
localparam TX_WAIT_STATES = 4;

input  wire clk;
input  wire rst_n; // Synchronous reset, high when clk is stable!
input  wire rx0tx0_link; // RX0/TX0 link up indication
output wire rx0_loopback; // RX0->TX0 loopback
input  wire rx0_clk;
input  wire [7:0] rx0_d; // Byte read node data
input  wire rx0_dv; // Read node data valid R0
input  wire rx0_err; // RX error
output wire tx0_clk;
output wire [7:0] tx0_d; // Byte write node data
output wire tx0_dv; // Write node data valid R0
input  wire tx0_dr; // Ready for node data
output reg  tx0_err = 0; // TX error
input  wire rx1tx1_link; // RX1/TX1 link up indication
output wire rx1_loopback; // RX1->TX1 loopback
input  wire rx1_clk;
input  wire [7:0] rx1_d; // Byte read node data
input  wire rx1_dv; // Read node data valid R1
input  wire rx1_err; // RX error
output wire tx1_clk;
output wire [7:0] tx1_d; // Byte node write data
output wire tx1_dv; // Write node data valid R1
input  wire tx1_dr; // Ready for node data
output reg  tx1_err = 0; // TX error
input  wire [7:0] rx0_ch_d; // Byte read channel data
input  wire rx0_ch_dv; // Read channel data valid R0
output wire rx0_ch_dr; // Read channel data ready R0
output reg  [7:0] tx0_ch_d = 0; // Byte write channel data
output wire [CHW-1:0] rx0_tx0_ch; // Channel address (0 - NR_CHANNELS-1)
input  wire [7:0] rx1_ch_d; // Byte read channel data
input  wire rx1_ch_dv; // Read channel data valid R1
output wire rx1_ch_dr; // Read channel data ready R1
output reg  [7:0] tx1_ch_d = 0; // Byte write channel data
output wire [CHW-1:0] rx1_tx1_ch; // Channel address (0 - NR_CHANNELS-1)
output reg  [12:0] rx0_node_pos = 0;
output reg  [13:0] rx0_c_s = 0; // Command/status ( + command/status bit)
output reg  [2:0] rx0_status = 0;
output reg  [27:0] rx0_delay = 0;
output reg  [12:0] rx1_node_pos = 0;
output reg  [13:0] rx1_c_s = 0; // Command/status ( + command/status bit)
output reg  [2:0] rx1_status = 0;
output reg  [27:0] rx1_delay = 0;
output reg  [2:0] tx0_status = 0;
input  wire [12:0] tx0_c_s; // Command/status
output reg  [2:0] tx1_status = 0;
input  wire [12:0] tx1_c_s; // Command/status
output reg  tx0rx0_valid = 0; // rx0_node_pos, rx0_c_s, rx0_delay valid
output reg  tx1rx1_valid = 0; // rx1_node_pos, rx1_c_s, rx1_delay valid
output wire ring_reset_pending;
output wire [63:0] clk_count; // Actual master clock count

// Registers and wires
reg  [63:0] clk_m_count = 0;
reg         clk_m_reset_done = 0;
/*---------------------------*/
reg   [6:0] rx0_d_c;
reg   [7:0] rx00_d_i = 0;
reg   [7:0] rx01_d_i = 0;
reg         dv00_en = 0;
reg         dv01_en = 0;
reg         rx0_dv_i = 0;
reg         rx0_parity_ok = 0;
wire        rx0_parity_ok_c;
reg         rx0_dir = 0; // = 1 when ring direction is CCW
reg         rx0_dir_sync = 0; // = 1 when ring direction is CW
reg  [NRBW-1:0] rx0_nb_bytes = 0;
wire        rx0_idle;
wire        rx0_ready;
reg         rx0_error = 0;
wire        rx0_cmd_nop;
reg         rx0_cmd_nop_i = 0;
wire        rx0_clk_sync_cmd;
wire        rx0_clk_sync_set_cmd;
wire        rx0_clk_reset_cmd;
/*---------------------------*/
reg   [7:0] tx0_d_i = 0;
reg         tx0_dv_i = 0;
reg   [2:0] tx0_status_i = 0;
reg  [12:0] tx0_c_s_i;
wire        tx0_idle;
wire        tx0_init;
wire        tx0_wait;
wire        tx0_ready;
reg  [NRBW-1:0] tx0_nb_bytes = 0;
reg  [NRBW-1:0] tx0_max_bytes = 0;
reg         tx0_clk_reset_cmd_sent = 0;
reg  [2:0]  tx0_wait_states = 0;
/*---------------------------*/
reg   [6:0] rx1_d_c;
reg   [7:0] rx11_d_i = 0;
reg   [7:0] rx10_d_i = 0;
reg         dv11_en = 0;
reg         rx1_dv_i = 0;
wire  [7:0] rx1_node_pos_c;
reg         rx1_node_pos_carry = 0;
wire        rx1_node_pos_inc;
reg         rx1_parity_ok = 0;
wire        rx1_parity_ok_c;
reg         rx1_dir = 0; // = 1 when ring direction is CW
reg         rx1_dir_sync = 0; // = 1 when ring direction is CCW
reg  [NRBW-1:0] rx1_nb_bytes = 0;
wire [27:0] rx1_delay_c;
wire        rx1_idle;
wire        rx1_ready;
reg         rx1_error = 0;
wire        rx1_cmd_nop;
reg         rx1_cmd_nop_i = 0;
wire        rx1_clk_sync_cmd;
wire        rx1_clk_sync_set_cmd;
wire        rx1_clk_reset_cmd;
/*---------------------------*/
reg   [7:0] tx1_d_i = 0;
reg         tx1_dv_i = 0;
reg   [2:0] tx1_status_i = 0;
reg  [12:0] tx1_c_s_i;
wire        tx1_idle;
wire        tx1_init;
wire        tx1_wait;
wire        tx1_ready;
reg  [NRBW-1:0] tx1_nb_bytes = 0;
reg  [NRBW-1:0] tx1_max_bytes = 0;
reg         tx1_clk_reset_cmd_sent= 0;
reg  [2:0]  tx1_wait_states = 0;
/*---------------------------*/
reg [10:0] delay_count = 0;
reg        delay_count_en = 0;
reg [4:0]  delay_nb_samples = 0;
reg [14:0] tx0rx0_delay_count = 0;
reg [14:0] tx1rx1_delay_count = 0;
/*---------------------------*/
wire       tx0_clk_sync_c_s;
wire       tx1_clk_sync_c_s;
wire       tx0rx0_delay_set;
wire       tx1rx1_delay_set;
/*---------------------------*/
reg [12:0] cmd_sync_0 = `CLK_SYNC_0; // Constant!
reg [6:0]  tx0_tmp_c;
reg [6:0]  tx1_tmp_c;
reg        rx0_reset = 0;
reg        rx1_reset = 0;
reg        tx0_reset = 0;
reg        tx1_reset = 0;
wire       tx0_ring_reset;
wire       tx1_ring_reset;
wire       ring_reset;

/*============================================================================*/
initial begin : param_check // Parameter check
/*============================================================================*/
    if ( !(( 0 == PREAMBLE_SFD ) || ( 1 == PREAMBLE_SFD ))) begin
        $display("PREAMBLE_SFD parameter should be 0 or 1!");
        $finish;
    end
    if ( NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
end // param_check

localparam [4:0] CLK_10NS  = 5'h10; // clk = 100MHz

/*============================================================================*/
initial begin
/*============================================================================*/
    rx0_status = `eR_IDLE;
    rx1_status = `eR_IDLE;
    cmd_sync_0 = `CLK_SYNC_0;
end

/*============================================================================*/
function [7:0] set_parity( input [6:0] byte_6_0 ); // Even parity
/*============================================================================*/
    begin
        set_parity = { ~( ^byte_6_0 ), byte_6_0 };
    end
endfunction

/*=============================================================================/
RING         | SLV0    |  | SLV1    |         | SLV8190 |  | SLV8191 |
|  +------+  +---------+  +---------+         +---------+  +---------+  +------+
|  |MASTER|  | NP 8191 |  | NP 8190 |         | NP 1    |  | NP 0    |  |MASTER|
CCW|  RX0 |<-| TX0 RX1 |<-| TX0 RX1 |<- - - <-| TX0 RX1 |<-| TX0 RX1 |<-| TX1  |
|  |      |  | NP 0    |    NP 1    |         | NP 8190 |    NP 8191 |  |      |
CW |  TX0 |->| RX0 TX1 |->| RX0 TX1 |->- - ->-| RX0 TX1 |->| RX0 TX1 |->| RX1  |
   +------+  +---------+  +---------+         +---------+  +---------+  +------+
/=============================================================================*/

assign tx0_ring_reset = ( `RING_RESET == tx0_c_s );
assign tx1_ring_reset = ( `RING_RESET == tx1_c_s );
assign ring_reset = ( tx0_ring_reset || tx1_ring_reset ) &&
    (( `RING_RESET == rx0_c_s[12:0] ) || ( `RING_RESET == rx1_c_s[12:0] ));
assign ring_reset_pending = rx0_reset & rx1_reset & tx0_reset & tx1_reset;

assign rx0_idle = ( `eR_IDLE == rx0_status );
assign rx0_ready = ( `eR_READY == rx0_status );
assign rx0_cmd_nop = ( `CMD_NOP == rx0_c_s[12:0] ) && rx0_c_s[13];
assign rx0_clk_sync_cmd = ( `CLK_SYNC_0 >> 3 ) == rx0_c_s[12:3];
assign rx0_clk_sync_set_cmd = rx0_clk_sync_cmd && rx0_c_s[2];
assign rx0_clk_reset_cmd = ( `CLK_RESET == rx0_c_s[12:0] );
assign rx0_parity_ok_c = ( rx0_d[7] == ~( ^rx0_d[6:0] ));
assign rx0_ch_dr = !( rx0_nb_bytes < CHANNEL_OFFSET ) && rx0_ready && rx1_ready;
assign rx0_tx0_ch = rx0_ch_dr ? ( rx0_nb_bytes - CHANNEL_OFFSET ) : 0;

assign tx0_idle = ( `eR_IDLE == tx0_status );
assign tx0_init = ( `eR_INIT == tx0_status );
assign tx0_wait = ( `eR_WAIT == tx0_status );
assign tx0_ready = ( `eR_READY == tx0_status );
assign tx0_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == tx0_c_s[12:3];
assign tx0rx0_delay_set = |tx0rx0_delay_count;

/*============================================================================*/
always @(posedge rx0_clk) begin : rx0_process
/*============================================================================*/
    rx0_error <= 0;
    rx00_d_i  <= rx0_d;
    rx01_d_i  <= rx0_d;
    rx0_dv_i  <= rx0_dv;

    if ( rx0_dv ) begin
        rx0_nb_bytes  <= rx0_nb_bytes + 1;
        rx0_parity_ok <= rx0_parity_ok_c;

        if (( NODE_POS_OFFSET == rx0_nb_bytes ) && rx0_parity_ok_c ) begin
            rx0_node_pos[6:0] <= rx0_d[6:0];
            rx00_d_i <= set_parity( 0 ); // Set CW loopback node position to zero
            tx0rx0_valid <= 0;
        end

        if ((( NODE_POS_OFFSET + 1 ) == rx0_nb_bytes ) && rx0_parity_ok_c && rx0_parity_ok ) begin
            rx0_dir <= ( `CCW_RDIR == rx0_d[6] );
            rx0_dir_sync <= 0;
            if ( tx0_init ) begin
                rx0_dir_sync <= rx0_dir_sync || ( `CW_RDIR == rx0_d[6] );
            end
            rx0_node_pos[12:7] <= rx0_d[5:0];
            rx00_d_i <= set_parity( 0 ); // Set CW loopback node position to zero
        end

        if ((( NODE_POS_OFFSET + 2 ) == rx0_nb_bytes ) && rx0_parity_ok_c ) begin
            rx00_d_i <= set_parity( `CMD_NOP & 7'h3F ); // NOP loopback command/status
        end

        if ((( NODE_POS_OFFSET + 3 ) == rx0_nb_bytes ) && rx0_parity_ok_c && rx0_parity_ok ) begin
            rx0_c_s <= {rx0_d[6:0], rx01_d_i[6:0]};
            rx00_d_i <= set_parity( `CMD_NOP >> 7 ); // NOP loopback status
            if ( tx1_init && (( `CLK_SYNC_SET_0 >> 2 ) == rx01_d_i[6:2] )) begin // Check for CLK_SYNC_SET cmd
                rx00_d_i[7:6] <= 2'b01; // NOP loopback command parity
            end
        end

        if (( NODE_POS_OFFSET + 4 ) == rx0_nb_bytes ) begin
            if ( tx0_init && rx0_clk_sync_set_cmd && rx0_parity_ok_c ) begin
                rx0_delay[6:0] <= rx0_d[6:0];
            end
            rx00_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 5 ) == rx0_nb_bytes ) begin
            if ( tx0_init && rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    rx0_delay[13:7] <= rx0_d[6:0];
                    rx0_parity_ok <= 1;
                end
            end
            rx00_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 6 ) == rx0_nb_bytes ) begin
            if ( tx0_init && rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    rx0_delay[20:14] <= rx0_d[6:0];
                    rx0_parity_ok <= 1;
                end
            end
            rx00_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 7 ) == rx0_nb_bytes ) begin
            if ( tx0_init && rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    rx0_delay[27:21] <= rx0_d[6:0];
                    rx0_parity_ok <= 1;
                    tx0rx0_valid <= 1;
                end
            end
            rx00_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if ( rx0_ch_dr ) begin
            tx0_ch_d <= rx0_d;
        end
    end else begin
        rx0_nb_bytes <= 0;
        rx0_reset <= rx0_reset || ring_reset;
    end

    if (( rx0_dv_i && !tx0_dr ) || rx0_error ) begin
        // This is not allowed!
        rx0_error <= 1;
    end

    if ( delay_count[10] ) begin // ~10us delay counting passed!
        rx0_status <= `eR_NO_RR; // Redundant ring broken
    end

    if ( !rst_n || ( rx0_reset && !rx0_dv && !ring_reset )) begin
        rx0_dir <= 0;
        rx0_dir_sync <= 0;
        rx0_status <= `eR_IDLE;
        rx0_nb_bytes <= 0;
        rx00_d_i <= 0;
        rx01_d_i <= 0;
        rx0_dv_i <= 0;
        rx0_reset <= 0;
    end
end // rx0_process

/*============================================================================*/
always @(posedge rx0_clk) begin : tx0_process
/*============================================================================*/
    tx0_d_i <= 0;
    tx0_dv_i <= 0;

    if ( `eR_INIT == tx0_status_i ) begin
        if ( tx0_status != `eR_INIT ) begin
            tx0_nb_bytes <= 0;
        end
        tx0_status <= `eR_INIT;
        tx0_max_bytes <= 8; // Node position, command/status and delay
    end

    if ( tx0_ready ) begin
        tx0_max_bytes <= NR_CHANNELS + 4; // Plus node position, command/status
    end

    if (( tx0_init || tx0_wait ) && rx0_cmd_nop ) begin
        rx1_cmd_nop_i <= 1; // rx1_cmd_nop received!
    end

    if ( tx0_dr ) begin
        if ( tx0_wait && ( tx1_wait || tx1_ready ) && !rx0_dv && rx1_cmd_nop_i ) begin
            tx0_wait_states <= tx0_wait_states + 1;
            if ( TX_WAIT_STATES == tx0_wait_states ) begin
                rx1_cmd_nop_i <= 0;
                tx0_wait_states <= 0;
                tx0_status <= `eR_READY;
            end
        end
        if ( tx0_init || tx0_ready ) begin
            if ( 0 == tx0_nb_bytes ) begin
                tx0_d_i <= set_parity( 0 ); // Node position = 0, low byte
            end
            if ( 1 == tx0_nb_bytes ) begin // Node position = 0, high byte
                tx0_d_i <= set_parity( {`CW_RDIR, 6'd0} );
            end
            if ( tx0_nb_bytes < tx0_max_bytes ) begin
                tx0_nb_bytes <= tx0_nb_bytes + 1;
                tx0_dv_i <= 1;
            end
        end
        if ( tx0_ready ) begin
            if ( tx0_clk_reset_cmd_sent ) begin
                if ( 2 == tx0_nb_bytes ) begin
                    tx0_c_s_i <= tx0_c_s;
                    tx0_d_i <= set_parity( tx0_c_s[6:0] );
                    if ( clk_m_reset_done && ( `CMD_NOP == tx0_c_s )) begin
                        tx0_d_i <= set_parity( clk_m_count[6:0] );
                    end
                end
                if ( 3 == tx0_nb_bytes ) begin
                    tx0_tmp_c = `MASTER_CLK_10L >> 7;
                    tx0_d_i <= set_parity( {1'b1, tx0_c_s[12:7]} ); // Set CMD bit
                    if ( clk_m_reset_done && ( `CMD_NOP == tx0_c_s_i )) begin // Status, reset CMD bit
                        tx0_d_i <= set_parity( {1'b0, tx0_tmp_c[5:3], clk_m_count[9:7]} );
                    end
                end
            end else begin
                if ( 2 == tx0_nb_bytes ) begin
                    tx0_d_i <= set_parity( `CLK_RESET & 7'h3F );
                end
                if ( 3 == tx0_nb_bytes ) begin // Set CMD bit
                    tx0_tmp_c = `CLK_RESET >> 7;
                    tx0_d_i <= set_parity( {1'b1, tx0_tmp_c[5:0]} );
                    tx0_clk_reset_cmd_sent <= 1;
                end
            end
        end
        if ( tx0_init ) begin
            tx0_clk_reset_cmd_sent <= 0;
            if ( tx0_clk_sync_c_s ) begin
                if ( 2 == tx0_nb_bytes ) begin
                    tx0_d_i <= set_parity( {tx0_c_s[6:3], tx0rx0_delay_set, tx0_c_s[1:0]} );
                end
                if ( 3 == tx0_nb_bytes ) begin // Set CMD bit
                    tx0_d_i <= set_parity( {1'b1, tx0_c_s[12:7]} );
                end
            end else begin // Default 1 delay sample, single delay measurement
                if ( 2 == tx0_nb_bytes ) begin
                    tx0_d_i <= set_parity( {cmd_sync_0[6:3], tx0rx0_delay_set, cmd_sync_0[1:0]} );
                end
                if ( 3 == tx0_nb_bytes ) begin // Set CMD bit
                    tx0_d_i <= set_parity( {1'b1, cmd_sync_0[12:7]} );
                end
            end
            if ( 4 == tx0_nb_bytes ) begin
                tx0_d_i <= set_parity( tx0rx0_delay_count[6:0] );
            end
            if ( 5 == tx0_nb_bytes ) begin
                tx0_d_i <= set_parity( tx0rx0_delay_count[13:7] );
            end
            if ( 6 == tx0_nb_bytes ) begin
                tx0_d_i <= set_parity( { 6'd0, tx0rx0_delay_count[14]} );
            end
            if ( 7 == tx0_nb_bytes ) begin
                tx0_d_i <= set_parity( 0 );
            end
        end
    end else begin
        tx0_nb_bytes <= 0;
        if ( rx0_dir && rx0_dir_sync ) begin // Loopback or broken ring message received!
            if ( tx0_init ) begin            // rx0_dir == CCW, rx1_dir_sync == CW
                tx0_status <= `eR_WAIT;
            end
        end
        tx0_reset <= tx0_reset || ring_reset;
    end
    if ( !rst_n || ( tx0_reset && !tx0_dr && !ring_reset )) begin
        rx1_cmd_nop_i <= 0;
        tx0_status <= `eR_IDLE;
        tx0_nb_bytes <= 0;
        tx0_clk_reset_cmd_sent <= 0;
        tx0_wait_states <= 0;
        tx0_c_s_i <= 0;
        tx0_reset <= 0;
    end
end // tx0_process

assign rx1_idle = ( `eR_IDLE == rx1_status );
assign rx1_ready = ( `eR_READY == rx1_status );
assign rx1_cmd_nop = ( `CMD_NOP == rx1_c_s[12:0] ) && rx1_c_s[13];
assign rx1_clk_sync_cmd = ( `CLK_SYNC_0 >> 3 ) == rx1_c_s[12:3];
assign rx1_clk_sync_set_cmd = rx1_clk_sync_cmd && rx1_c_s[2];
assign rx1_clk_reset_cmd = ( `CLK_RESET == rx1_c_s[12:0] );
assign rx1_parity_ok_c = ( rx1_d[7] == ~( ^rx1_d[6:0] ));
assign rx1_ch_dr = !( rx1_nb_bytes < CHANNEL_OFFSET ) && rx0_ready && rx1_ready;
assign rx1_tx1_ch = rx1_ch_dr ? ( rx1_nb_bytes - CHANNEL_OFFSET ) : 0;

assign tx1_idle = ( `eR_IDLE == tx1_status );
assign tx1_init = ( `eR_INIT == tx1_status );
assign tx1_wait = ( `eR_WAIT == tx1_status );
assign tx1_ready = ( `eR_READY == tx1_status );
assign tx1_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == tx1_c_s[12:3];
assign tx1rx1_delay_set = |tx1rx1_delay_count;

/*============================================================================*/
always @(posedge rx1_clk) begin : rx1_process
/*============================================================================*/
    rx1_error <= 0;
    rx11_d_i  <= rx1_d;
    rx10_d_i  <= rx1_d;
    rx1_dv_i  <= rx1_dv;

    if ( rx1_dv ) begin
        rx1_nb_bytes  <= rx1_nb_bytes + 1;
        rx1_parity_ok <= rx1_parity_ok_c;

        if (( NODE_POS_OFFSET == rx1_nb_bytes ) && rx1_parity_ok_c ) begin
            rx1_node_pos[6:0] <= rx1_d[6:0];
            rx11_d_i <= set_parity( 0 ); // Set CCW loopback node position to zero
            tx1rx1_valid <= 0;
        end

        if ((( NODE_POS_OFFSET + 1 ) == rx1_nb_bytes ) && rx1_parity_ok_c && rx1_parity_ok ) begin
            rx1_dir <= ( `CW_RDIR == rx1_d[6] );
            rx1_dir_sync <= 0;
            if ( tx1_init ) begin
                rx1_dir_sync <= rx1_dir_sync || ( `CCW_RDIR == rx1_d[6] );
            end
            rx1_node_pos[12:7] <= rx1_d[5:0];
            rx11_d_i <= set_parity( 7'h40 ); // Set CCW loopback node position to zero
        end

        if ((( NODE_POS_OFFSET + 2 ) == rx1_nb_bytes ) && rx1_parity_ok_c ) begin
            rx11_d_i <= set_parity( `CMD_NOP & 7'h3F ); // NOP loopback status
        end

        if ((( NODE_POS_OFFSET + 3 ) == rx1_nb_bytes ) && rx1_parity_ok_c && rx1_parity_ok ) begin
            rx1_c_s <= {rx1_d[6:0], rx10_d_i[6:0]};
            rx11_d_i <= set_parity( `CMD_NOP >> 7 ); // NOP loopback status
            if ( tx0_init && (( `CLK_SYNC_SET_0 >> 2 ) == rx10_d_i[6:2] )) begin // Check for CLK_SYNC_SET cmd
                rx11_d_i[7:6] <= 2'b01; // NOP loopback command parity
            end
        end

        if (( NODE_POS_OFFSET + 4 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd && rx1_parity_ok_c ) begin
                rx1_delay[6:0] <= rx1_d[6:0];
            end
            rx11_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 5 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    rx1_delay[13:7] <= rx1_d[6:0];
                    rx1_parity_ok <= 1;
                end
            end
            rx11_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 6 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    rx1_delay[20:14] <= rx1_d[6:0];
                    rx1_parity_ok <= 1;
                end
            end
            rx11_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if (( NODE_POS_OFFSET + 7 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    rx1_delay[27:21] <= rx1_d[6:0];
                    rx1_parity_ok <= 1;
                    tx1rx1_valid <= 1;
                end
            end
            rx11_d_i <= set_parity( 0 ); // Reset loopback delay to zero
        end

        if ( rx1_ch_dr ) begin
            tx1_ch_d <= rx1_d;
        end
    end else begin
        rx1_nb_bytes <= 0;
        rx1_reset <= rx1_reset || ring_reset;
    end

    if (( rx1_dv_i && !tx1_dr ) || rx1_error ) begin
        // This is not allowed!
        rx1_error <= 1;
    end

    if ( delay_count[10] ) begin // ~10us delay counting passed!
        rx1_status <= `eR_NO_RR; // Redundant ring broken
    end

    if ( !rst_n || ( rx1_reset && !rx1_dv && !ring_reset )) begin
        rx1_dir <= 0;
        rx1_dir_sync <= 0;
        rx1_status <= `eR_IDLE;
        rx1_nb_bytes <= 0;
        rx11_d_i <= 0;
        rx10_d_i <= 0;
        rx1_dv_i <= 0;
        rx1_reset <= 0;
    end
end // rx1_process

/*============================================================================*/
always @(posedge rx1_clk) begin : tx1_process
/*============================================================================*/
    tx1_d_i <= 0;
    tx1_dv_i <= 0;

    if ( `eR_INIT == tx1_status_i ) begin
        if ( tx1_status != `eR_INIT ) begin
            tx1_nb_bytes <= 0;
        end
        tx1_status <= `eR_INIT;
        tx1_max_bytes <= 8; // Node position, command/status and delay
    end

    if ( tx1_ready ) begin
        tx1_max_bytes <= NR_CHANNELS + 4; // Plus node position, command/status
    end

    if (( tx1_init || tx1_wait ) && rx0_cmd_nop ) begin
        rx0_cmd_nop_i <= 1; // rx0_cmd_nop received!
    end

    if ( tx1_dr ) begin
        if ( tx1_wait && ( tx0_wait || tx0_ready ) && !rx1_dv && rx0_cmd_nop_i ) begin
            tx1_wait_states <= tx1_wait_states + 1;
            if ( TX_WAIT_STATES == tx1_wait_states ) begin
                rx0_cmd_nop_i <= 0;
                tx1_wait_states <= 0;
                tx1_status <= `eR_READY;
            end
        end
        if ( tx1_init || tx1_ready ) begin
            if ( 0 == tx1_nb_bytes ) begin
                tx1_d_i <= set_parity( 0 ); // Node position = 0, low byte
            end
            if ( 1 == tx1_nb_bytes ) begin // Node position = 0, high byte
                tx1_d_i <= set_parity( {`CCW_RDIR, 6'd0} );
            end
            if ( tx1_nb_bytes < tx1_max_bytes ) begin
                tx1_nb_bytes <= tx1_nb_bytes + 1;
                tx1_dv_i <= 1;
            end
        end
        if ( tx1_ready ) begin
            if ( tx1_clk_reset_cmd_sent ) begin
                if ( 2 == tx1_nb_bytes ) begin
                    tx1_c_s_i <= tx1_c_s;
                    tx1_d_i <= set_parity( tx1_c_s[6:0] );
                    if ( clk_m_reset_done && ( `CMD_NOP == tx1_c_s )) begin
                        tx1_d_i <= set_parity( clk_m_count[6:0] );
                    end
                end
                if ( 3 == tx1_nb_bytes ) begin
                    tx1_tmp_c = `MASTER_CLK_10L >> 7;
                    tx1_d_i <= set_parity( {1'b1, tx1_c_s[12:7]} ); // Set CMD bit
                    if ( clk_m_reset_done && ( `CMD_NOP == tx1_c_s_i )) begin // Status, reset CMD bit
                        tx1_d_i <= set_parity( {1'b0, tx1_tmp_c[5:3], clk_m_count[9:7]} );
                    end
                end
            end else begin
                if ( 2 == tx1_nb_bytes ) begin
                    tx1_d_i <= set_parity( `CLK_RESET & 7'h3F );
                end
                if ( 3 == tx1_nb_bytes ) begin // Set CMD bit
                    tx1_tmp_c = `CLK_RESET >> 7;
                    tx1_d_i <= set_parity( {1'b1, tx1_tmp_c[5:0]} );
                    tx1_clk_reset_cmd_sent <= 1;
                end
            end
        end
        if ( tx1_init ) begin
            tx1_clk_reset_cmd_sent <= 0;
            if ( tx1_clk_sync_c_s ) begin
                if ( 2 == tx1_nb_bytes ) begin
                    tx1_d_i <= set_parity( {tx1_c_s[6:3], tx1rx1_delay_set, tx1_c_s[1:0]} );
                end
                if ( 3 == tx1_nb_bytes ) begin // Set CMD bit
                    tx1_d_i <= set_parity( {1'b1, tx1_c_s[12:7]} );
                end
            end else begin // Default 1 delay sample, single delay measurement
                if ( 2 == tx1_nb_bytes ) begin
                    tx1_d_i <= set_parity( {cmd_sync_0[6:3], tx1rx1_delay_set, cmd_sync_0[1:0]} );
                end
                if ( 3 == tx1_nb_bytes ) begin // Set CMD bit
                    tx1_d_i <= set_parity( {1'b1, cmd_sync_0[12:7]} );
                end
            end
            if ( 4 == tx1_nb_bytes ) begin
                tx1_d_i <= set_parity( tx1rx1_delay_count[6:0] );
            end
            if ( 5 == tx1_nb_bytes ) begin
                tx1_d_i <= set_parity( tx1rx1_delay_count[13:7] );
            end
            if ( 6 == tx1_nb_bytes ) begin
                tx1_d_i <= set_parity( { 6'd0, tx1rx1_delay_count[14]} );
            end
            if ( 7 == tx1_nb_bytes ) begin
                tx1_d_i <= set_parity( 0 );
            end
        end
    end else begin
        tx1_nb_bytes <= 0;
        if ( rx1_dir && rx1_dir_sync ) begin // Loopback or broken ring message received!
            if ( tx1_init ) begin            // rx1_dir == CW, rx1_dir_sync == CCW
                tx1_status <= `eR_WAIT;
            end
        end
        tx1_reset <= tx1_reset || ring_reset;
    end
    if ( !rst_n || ( tx1_reset && !tx1_dr && !ring_reset )) begin
        rx0_cmd_nop_i <= 0;
        tx1_status <= `eR_IDLE;
        tx1_nb_bytes <= 0;
        tx1_clk_reset_cmd_sent <= 0;
        tx1_wait_states <= 0;
        tx1_c_s_i <= 0;
        tx1_reset <= 0;
    end
end // tx1_process

// TX->RX->FPGA->TX->RX. To determine the propagation delay, the TX->RX delays
// should be divided by two, but the internal FPGA RX->TX copy clock cycle
// should not. Therefore the clocked delay calculation has an offset.
localparam CLK_DELAY_OFFSET = 8; // 8 * 10ns clock cycles

reg [1:0] rx0_clk_i = 0;
reg [1:0] rx1_clk_i = 0;
reg [1:0] tx0_clk_i = 0;
reg [1:0] tx1_clk_i = 0;
reg tx0_rr_request = 0;
reg tx1_rr_request = 0;
wire tx0rx0_delay_count_zero;
wire tx1rx1_delay_count_zero;
wire [9:0] clk_delay_tx0_offset;
wire [9:0] clk_delay_tx1_offset;

assign clk_count = clk_m_count;
assign tx0rx0_delay_count_zero = ( 0 == tx0rx0_delay_count );
assign tx1rx1_delay_count_zero = ( 0 == tx1rx1_delay_count );
assign clk_delay_tx0_offset = ( CLK_DELAY_OFFSET << tx0_c_s[1:0] );
assign clk_delay_tx1_offset = ( CLK_DELAY_OFFSET << tx1_c_s[1:0] );

/*============================================================================*/
always @(posedge clk) begin : handle_ports
/*============================================================================*/
    rx0_clk_i <= { rx0_clk_i[0], rx0_clk };
    rx1_clk_i <= { rx1_clk_i[0], rx1_clk };
    tx0_clk_i <= { tx0_clk_i[0], tx0_clk };
    tx1_clk_i <= { tx1_clk_i[0], tx1_clk };

    clk_m_count <= clk_m_count + 1;

    if ( tx0_status_i == tx0_status ) begin
        tx0_status_i <= `eR_IDLE;
    end
    if ( tx1_status_i == tx1_status ) begin
        tx1_status_i <= `eR_IDLE;
    end

    if ( delay_count_en ) begin
        delay_count <= delay_count + 1;
    end

    if ( !tx0_rr_request && !tx1_rr_request ) begin
        if ( tx0_ring_reset ) begin
            tx0_rr_request <= 1; // Ring reset request
        end if ( tx1_ring_reset ) begin
            tx1_rr_request <= 1;
        end
    end

    if ( tx0_idle && tx1_idle && !ring_reset ) begin
        if (( `eR_IDLE == tx0_status_i ) && ( 2'b10 == rx1_clk_i )) begin
            dv11_en <= 0; // Disable when clk low, next cycle!
        end
        if (( `eR_IDLE == tx1_status_i ) && ( 2'b10 == rx0_clk_i )) begin
            dv00_en <= 0; // Disable when clk low, next cycle!
        end
        if ( rx0tx0_link && !rx0_dv && !tx1_rr_request ) begin
            if ( 2'b10 == rx0_clk_i ) begin
                tx0_rr_request <= 0;
                tx0_status_i <= `eR_INIT;
                dv00_en <= 0;
            end
            if ( 2'b10 == rx1_clk_i ) begin
                dv11_en <= 1; // RX1 loopback!
            end
            delay_count <= clk_delay_tx0_offset;
        end else if ( rx1tx1_link && !rx1_dv && !tx0_rr_request  ) begin
            if ( 2'b10 == rx1_clk_i ) begin
                tx1_rr_request <= 0;
                tx1_status_i <= `eR_INIT;
                dv11_en <= 0;
            end
            if ( 2'b10 == rx0_clk_i ) begin
                dv00_en <= 1; // RX0 loopback!
            end
            delay_count <= clk_delay_tx1_offset;
        end
        clk_m_reset_done <= 0;
        delay_nb_samples <= 0;
        delay_count_en <= 0;
        tx0rx0_delay_count <= 0;
        tx1rx1_delay_count <= 0;
    end

    if ( tx0_wait && tx1_idle ) begin
        if (( 2'b10 == rx1_clk_i ) && !tx0_dv && tx0_dr ) begin
            dv11_en <= 0; // Disable when clk low, next cycle!
        end
        if (( 2'b10 == rx0_clk_i ) && !dv11_en && !rx0_dv && !rx0_dv_i  ) begin
            dv00_en <= 1; // Enable when clk low, next cycle!
        end
        if ( rx1tx1_link && dv00_en ) begin
            delay_count <= clk_delay_tx1_offset;
            delay_nb_samples <= 0;
            tx1_status_i <= `eR_INIT;
        end
    end

    if ( tx1_wait && tx0_idle ) begin
        if (( 2'b10 == rx0_clk_i ) && !tx1_dv && tx1_dr ) begin
            dv00_en <= 0; // Disable when clk low, next cycle!
        end
        if (( 2'b10 == rx1_clk_i ) && !dv00_en && !rx1_dv && !rx1_dv_i ) begin
            dv11_en <= 1; // Enable when clk low, next cycle!
        end
        if ( rx0tx0_link && dv11_en ) begin
            delay_count <= clk_delay_tx0_offset;
            delay_nb_samples <= 0;
            tx0_status_i <= `eR_INIT;
        end
    end

    if ( tx0_ready && tx1_ready ) begin
        delay_count_en <= 1; // Enable delay counting to detect broken ring
        if ( rx0_dv && rx1_dv ) begin
            delay_count_en <= 0; // Disable delay counting
            delay_count <= 0; // Reset delay counter
        end
    end

    if ( tx0_init ) begin
        if (( 2'b01 == tx0_clk_i ) && tx0_dv && !rx0_dv && tx0rx0_delay_count_zero ) begin
            delay_count_en <= 1;
        end
        if (( 2'b01 == rx0_clk_i ) && rx0_dv ) begin
            if ( delay_count_en && tx0rx0_delay_count_zero ) begin
                delay_nb_samples <= delay_nb_samples + 1;
                delay_count_en <= 0; // Disable delay counting
            end
        end
        if ( rx0_dir_sync && rx0_clk_sync_cmd && delay_count ) begin
            if (( 1 << tx0_c_s[1:0] ) == delay_nb_samples ) begin
                tx0rx0_delay_count <= {delay_count, 4'h0} >> ( tx0_c_s[1:0] + 1 );
                delay_count <= 0; // Reset delay counter
            end
        end
    end

    if ( tx1_init ) begin
        if (( 2'b01 == tx1_clk_i ) && tx1_dv && !rx1_dv && tx1rx1_delay_count_zero ) begin
            delay_count_en <= 1;
        end
        if (( 2'b01 == rx1_clk_i ) && rx1_dv ) begin
            if ( delay_count_en && tx1rx1_delay_count_zero ) begin
                delay_nb_samples <= delay_nb_samples + 1;
                delay_count_en <= 0; // Disable delay counting
            end
        end
        if ( rx1_dir_sync && rx1_clk_sync_cmd && delay_count ) begin
            if (( 1 << tx1_c_s[1:0] ) == delay_nb_samples ) begin
                tx1rx1_delay_count <= {delay_count, 4'h0} >> ( tx1_c_s[1:0] + 1 );
                delay_count <= 0; // Reset delay counter
            end
        end
    end

    if ( delay_count[10] ) begin // Redundant ring broken
        delay_count_en <= 0; // Disable delay counting
    end

    if ( !clk_m_reset_done && ( tx0_clk_reset_cmd_sent || tx1_clk_reset_cmd_sent )) begin
        clk_m_count <= 0; // Reset master clock!
        clk_m_reset_done <= 1;
    end

    if ( !rst_n ) begin
        clk_m_count <= 0;
        rx0_clk_i <= 0;
        rx1_clk_i <= 0;
        tx0_clk_i <= 0;
        tx1_clk_i <= 0;
        tx0_status_i <= `eR_IDLE;
        tx1_status_i <= `eR_IDLE;
        dv00_en <= 0;
        dv11_en <= 0;
    end
end // handle_ports

assign rx0_loopback = ( tx0_idle | tx0_wait ) & tx1_init;
assign rx1_loopback = ( tx1_idle | tx1_wait ) & tx0_init;
assign tx0_clk = rx0_clk;
assign tx1_clk = rx1_clk;
assign tx0_d = tx0_d_i | ( rx00_d_i & { 8{ rx0_loopback }} );
assign tx0_dv = tx0_dv_i | ( rx0_dv_i & dv00_en & rx0_loopback );
assign tx1_d = tx1_d_i | ( rx11_d_i & { 8{ rx1_loopback }} );
assign tx1_dv = tx1_dv_i | ( rx1_dv_i & dv11_en & rx1_loopback );

endmodule // sr2cb_m
