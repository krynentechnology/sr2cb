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
 *  Description: SR2CB slave node implementation.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "../lib/randomizer.v"
`include "sr2cb_def.v"

/*============================================================================*/
module sr2cb_s #(
/*============================================================================*/
    parameter NR_CHANNELS = 608,
    parameter [0:0] PREAMBLE_SFD = 1 )
    (
    clk, rst_n,
    rx0_clk, rx0_d, rx0_dv, rx0_err, // _d = data, _dv = data valid
    tx0_clk, tx0_d, tx0_dv, tx0_dr, tx0_err, // _dr = data ready
    rx1_clk, rx1_d, rx1_dv, rx1_err,
    tx1_clk, tx1_d, tx1_dv, tx1_dr, tx1_err,
    rx0_ch_d, rx0_ch_dv, rx0_ch_dr, tx0_ch_d, rx0_tx0_ch, // _ch = channel
    rx1_ch_d, rx1_ch_dv, rx1_ch_dr, tx1_ch_d, rx1_tx1_ch,
    rx0_node_pos, rx0_c_s, // _c_s = command/status
    rx1_node_pos, rx1_c_s,
    rx0_status, rx0_delay, rx0_rt_clk_count, rx0_clk_adjust_fast,
    rx1_status, rx1_delay, rx1_rt_clk_count, rx1_clk_adjust_fast
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
localparam CLK_SYNC_OFFSET = ( NODE_POS_OFFSET + 1 ) * 8 * 16; // *16 [3:0]
localparam CHW = clog2( NR_CHANNELS ); // Channel width
localparam NRBW = clog2( NR_CHANNELS + CHANNEL_OFFSET ); // RX bytes counter width

input  wire clk;
input  wire rst_n; // Synchronous reset, high when clk is stable!
input  wire rx0_clk;
input  wire [7:0] rx0_d; // Byte read node data
input  wire rx0_dv; // Read node data valid R0
input  wire rx0_err; // RX error
output wire tx0_clk;
output wire [7:0] tx0_d; // Byte write node data
output wire tx0_dv; // Write node data valid R0
input  wire tx0_dr; // Ready for node data
output wire tx0_err; // TX error
input  wire rx1_clk;
input  wire [7:0] rx1_d; // Byte read node data
input  wire rx1_dv; // Read node data valid R1
input  wire rx1_err; // RX error
output wire tx1_clk;
output wire [7:0] tx1_d; // Byte node write data
output wire tx1_dv; // Write node data valid R1
input  wire tx1_dr; // Ready for node data
output wire tx1_err; // TX error
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
output reg  [13:0] rx0_c_s = 0; // Command/status
output reg  [2:0] rx0_status = 0;
output reg  [27:0] rx0_delay = 0;
output wire [67:0] rx0_rt_clk_count; // Real-time R0 clock count
output reg  rx0_clk_adjust_fast = 0; // Monitor for external clk changes
output reg  [12:0] rx1_node_pos = 0;
output reg  [13:0] rx1_c_s = 0; // Command/status
output reg  [2:0] rx1_status = 0;
output reg  [27:0] rx1_delay = 0;
output wire [67:0] rx1_rt_clk_count; // Real-time R1 clock count
output reg  rx1_clk_adjust_fast = 0; // Monitor for external clk changes

// Registers and wires
reg         clk00_en = 0;
reg         clk01_en = 0;
reg   [7:0] rx00_d_i = 0;
reg   [7:0] rx01_d_i = 0;
reg         dv00_en = 0;
reg         dv01_en = 0;
reg         rx0_dv_i = 0;
wire  [7:0] rx0_node_pos_c;
reg         rx0_node_pos_carry = 0;
wire        rx0_node_pos_inc;
reg         rx0_parity_ok = 0;
wire        rx0_parity_ok_c;
reg  [NRBW-1:0] rx0_nb_bytes = 0;
wire [27:0] rx0_delay_c;
wire        rx0_idle;
wire        rx0_pre_init;
wire        rx0_init;
wire        rx0_wait;
wire        rx0_ready;
reg   [2:0] rx0_status_i = `eR_IDLE;
reg         rx0_error = 0;
wire        rx0_cmd_nop;
wire        rx0_clk_sync_c_s;
wire        rx0_clk_sync_cmd;
wire        rx0_clk_sync_set_cmd;
wire        rx0_clk_reset_cmd;
wire        rx0_mclk_status;
reg         rx0_delay_set = 0;
/*---------------------------*/
reg         clk11_en = 0;
reg         clk10_en = 0;
reg   [7:0] rx11_d_i = 0;
reg   [7:0] rx10_d_i = 0;
reg         dv11_en = 0;
reg         dv10_en = 0;
reg         rx1_dv_i = 0;
wire  [7:0] rx1_node_pos_c;
reg         rx1_node_pos_carry = 0;
wire        rx1_node_pos_inc;
reg         rx1_parity_ok = 0;
wire        rx1_parity_ok_c;
reg  [NRBW-1:0] rx1_nb_bytes = 0;
wire [27:0] rx1_delay_c;
wire        rx1_idle;
wire        rx1_pre_init;
wire        rx1_init;
wire        rx1_wait;
wire        rx1_ready;
reg   [2:0] rx1_status_i = `eR_IDLE;
reg         rx1_error = 0;
wire        rx1_cmd_nop;
wire        rx1_clk_sync_c_s;
wire        rx1_clk_sync_cmd;
wire        rx1_clk_sync_set_cmd;
wire        rx1_clk_reset_cmd;
wire        rx1_mclk_status;
reg         rx1_delay_set = 0;
/*---------------------------*/
reg [10:0] delay_count = 0;
reg [14:0] delay_rx01_count = 0;
reg [14:0] delay_rx10_count = 0;
/*---------------------------*/
reg  rx0_reset = 0;
reg  rx1_reset = 0;
wire rx0_ring_reset_cmd;
wire rx1_ring_reset_cmd;
wire ring_reset_cmd;
/*---------------------------*/

localparam LFSR_TAP_WIDTH = 8;
wire [LFSR_TAP_WIDTH-1:0] random_out;
/*============================================================================*/
randomizer #(
/*============================================================================*/
    .NR_CHANNELS( 1 ),
    .OUTPUT_WIDTH( LFSR_TAP_WIDTH ))
random (
    .clk(clk),
    .rndm_ch(1'b0),
    .rndm_seed(8'h0),
    .rndm_init(~rst_n),
    .rndm_out(random_out),
    .rndm_ready(1'b1)
);

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
localparam [13:0] RING_RESET_CMD = {1'b1, `RING_RESET};

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

assign rx0_ring_reset_cmd = ( RING_RESET_CMD == rx0_c_s );
assign rx1_ring_reset_cmd = ( RING_RESET_CMD == rx1_c_s );
assign ring_reset_cmd = ( rx0_ring_reset_cmd || rx1_ring_reset_cmd );

assign rx0_idle = ( `eR_IDLE == rx0_status );
assign rx0_pre_init = ( `eR_PRE_INIT == rx0_status );
assign rx0_init = ( `eR_INIT == rx0_status );
assign rx0_wait = ( `eR_WAIT == rx0_status );
assign rx0_ready = ( `eR_READY == rx0_status );
assign rx0_cmd_nop = ( `CMD_NOP == rx0_c_s[12:0] ) && rx0_c_s[13];
assign rx0_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == rx0_c_s[12:3];
assign rx0_clk_sync_cmd = rx0_clk_sync_c_s && rx0_c_s[13];
assign rx0_clk_sync_set_cmd = rx0_clk_sync_c_s && rx0_c_s[13] && rx0_c_s[2];
assign rx0_clk_reset_cmd = ( `CLK_RESET == rx0_c_s[12:0] ) && rx0_c_s[13];
assign rx0_mclk_status = (( `MASTER_CLK_10L >> 10 ) == rx0_c_s[13:10] );
assign rx0_node_pos_inc = !( rx1_init || rx1_wait );
assign rx0_delay_c = rx0_delay + { {9{1'b0}}, delay_rx01_count };
assign rx0_node_pos_c = {1'b0, rx0_d[6:0]} + 1;
assign rx0_parity_ok_c = ( rx0_d[7] == ~( ^rx0_d[6:0] ));
assign rx0_ch_dr = !( rx0_nb_bytes < CHANNEL_OFFSET ) && rx0_ready && rx1_ready;
assign rx0_tx0_ch = rx0_ch_dr ? ( rx0_nb_bytes - CHANNEL_OFFSET ) : 0;

/*============================================================================*/
always @(posedge rx0_clk) begin : rx0_process
/*============================================================================*/
    rx0_error <= 0;
    rx00_d_i  <= rx0_d;
    rx01_d_i  <= rx0_d;
    rx0_dv_i  <= rx0_dv;

    if ( `eR_INIT == rx0_status_i ) begin
        if ( rx0_status != `eR_INIT ) begin
            rx0_node_pos <= 0;
            rx0_c_s <= 0;
        end
        rx0_status <= `eR_INIT;
    end

    if (  rx0_clk_reset_cmd ) begin
        rx0_c_s <= {1'b1, `CMD_NOP};
    end

    if ( rx0_dv ) begin
        rx0_nb_bytes <= rx0_nb_bytes + 1;
        rx0_parity_ok <= rx0_parity_ok_c;

        if (( NODE_POS_OFFSET == rx0_nb_bytes ) && rx0_parity_ok_c ) begin
            rx0_node_pos[6:0] <= rx0_d[6:0];
            rx0_node_pos_carry <= rx0_node_pos_c[7];
            if ( rx0_node_pos_inc  ) begin
                rx01_d_i <= set_parity( rx0_node_pos_c[6:0] );
            end
        end

        if ((( NODE_POS_OFFSET + 1 ) == rx0_nb_bytes ) && rx0_parity_ok_c && rx0_parity_ok ) begin
            rx0_node_pos[12:7] <= rx0_d[5:0];
            if ( rx0_node_pos_inc ) begin
                rx01_d_i <= set_parity( {rx0_d[6], ( rx0_node_pos_carry ? rx0_node_pos_c[5:0] : rx0_d[5:0] )} );
            end
        end

        if ((( NODE_POS_OFFSET + 2 ) == rx0_nb_bytes ) && rx0_parity_ok_c ) begin
            if ( rx0_init ) begin
                if ( !rx0_delay_set ) begin // Disable clk_sync_set_cmd!
                    rx01_d_i <= set_parity( {rx0_d[6:3], 1'b0, rx0_d[1:0]} );
                end
            end
        end

        if ((( NODE_POS_OFFSET + 3 ) == rx0_nb_bytes ) && rx0_parity_ok_c && rx0_parity_ok ) begin
            rx0_c_s <= {rx0_d[6:0], rx00_d_i[6:0]};
            if ( rx0_init ) begin
                rx00_d_i <= set_parity( {1'b0, rx0_d[5:0]} ); // Reset command/status bit
            end
        end

        if (( NODE_POS_OFFSET + 4 ) == rx0_nb_bytes ) begin
            if ( rx0_clk_sync_set_cmd && rx0_parity_ok_c ) begin
                if ( rx0_init ) begin
                    rx0_delay[6:0] <= rx0_d[6:0];
                end
                if ( rx0_delay_set ) begin
                    rx01_d_i <= set_parity( rx0_delay_c[6:0] );
                end
            end
            if ( rx0_mclk_status ) begin
                rx0_c_s <= {1'b0, `CMD_NOP};
            end
        end

        if (( NODE_POS_OFFSET + 5 ) == rx0_nb_bytes ) begin
            if ( rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    if ( rx0_init ) begin
                        rx0_delay[13:7] <= rx0_d[6:0];
                    end
                    if ( rx0_delay_set ) begin
                        rx01_d_i <= set_parity( rx0_delay_c[13:7] );
                    end
                    rx0_parity_ok <= 1;
                end
            end
        end

        if (( NODE_POS_OFFSET + 6 ) == rx0_nb_bytes ) begin
            if ( rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    if ( rx0_init ) begin
                        rx0_delay[20:14] <= rx0_d[6:0];
                    end
                    if ( rx0_delay_set ) begin
                        rx01_d_i <= set_parity( rx0_delay_c[20:14] );
                    end
                    rx0_parity_ok <= 1;
                end
            end
        end

        if (( NODE_POS_OFFSET + 7 ) == rx0_nb_bytes ) begin
            if ( rx0_clk_sync_set_cmd ) begin
                rx0_parity_ok <= 0;
                if ( rx0_parity_ok_c && rx0_parity_ok ) begin
                    if ( rx0_init ) begin
                        rx0_delay[27:21] <= rx0_d[6:0];
                        // Start sending clk_sync_set_cmd to next node when
                        // R0 node delay TX1->RX1 has been determined!
                        rx0_delay_set <= |delay_rx01_count;
                    end
                    if ( rx0_delay_set ) begin
                        rx01_d_i <= set_parity( rx0_delay_c[27:21] );
                    end
                    rx0_parity_ok <= 1;
                end
            end
        end

        if ( rx0_ch_dr ) begin
            tx0_ch_d <= rx0_d;
            if ( rx0_ch_dv ) begin
                rx01_d_i <= rx0_ch_d;
            end
        end
    end
    else begin
        rx0_nb_bytes <= 0;
        rx00_d_i <= 0;

        if ( `eR_PRE_INIT == rx0_status_i ) begin
          rx0_status <= `eR_PRE_INIT;
        end

        if ( rx0_init && rx0_delay_set ) begin
            rx0_status <= `eR_WAIT; // CLK_SYNC_SET command received!
        end

        if ( rx0_wait && rx1_cmd_nop ) begin
            rx0_status <= `eR_READY;
        end

        rx0_reset <= rx0_reset || ring_reset_cmd;
    end

    if (( rx0_dv_i && !tx0_dr ) || rx0_error ) begin
        // This is not allowed!
        rx0_error <= 1;
    end

    if ( delay_count[10] ) begin // ~10us delay counting passed!
        rx0_status <= `eR_NO_RR; // Redundant ring broken
    end

    if ( !rst_n || ( rx0_reset && !rx0_dv && !ring_reset_cmd )) begin
        rx0_status <= `eR_IDLE;
        rx0_nb_bytes <= 0;
        rx00_d_i <= 0;
        rx01_d_i <= 0;
        rx0_dv_i <= 0;
        rx0_delay_set <= 0;
        rx0_c_s <= 0;
        rx0_reset <= 0;
    end
end // rx0_process

assign rx1_idle = ( `eR_IDLE == rx1_status );
assign rx1_pre_init = ( `eR_PRE_INIT == rx1_status );
assign rx1_init = ( `eR_INIT == rx1_status );
assign rx1_wait = ( `eR_WAIT == rx1_status );
assign rx1_ready = ( `eR_READY == rx1_status );
assign rx1_cmd_nop = ( `CMD_NOP == rx1_c_s[12:0] ) && rx1_c_s[13];
assign rx1_clk_sync_c_s = ( `CLK_SYNC_0 >> 3 ) == rx1_c_s[12:3];
assign rx1_clk_sync_cmd = rx1_clk_sync_c_s && rx1_c_s[13];
assign rx1_clk_sync_set_cmd = rx1_clk_sync_c_s && rx1_c_s[13] && rx1_c_s[2];
assign rx1_clk_reset_cmd = ( `CLK_RESET == rx1_c_s[12:0] ) && rx1_c_s[13];
assign rx1_mclk_status = (( `MASTER_CLK_10L >> 10 ) == rx1_c_s[13:10] );
assign rx1_node_pos_inc = !( rx0_init || rx0_wait );
assign rx1_delay_c = rx1_delay + { {9{1'b0}}, delay_rx10_count };
assign rx1_node_pos_c = {1'b0, rx1_d[6:0]} + 1;
assign rx1_parity_ok_c = ( rx1_d[7] == ~( ^rx1_d[6:0] ));
assign rx1_ch_dr = !( rx1_nb_bytes < CHANNEL_OFFSET ) && rx0_ready && rx1_ready;
assign rx1_tx1_ch = rx1_ch_dr ? ( rx1_nb_bytes - CHANNEL_OFFSET ) : 0;

/*============================================================================*/
always @(posedge rx1_clk) begin : rx1_process
/*============================================================================*/
    rx1_error <= 0;
    rx11_d_i  <= rx1_d;
    rx10_d_i  <= rx1_d;
    rx1_dv_i  <= rx1_dv;

    if ( `eR_INIT == rx1_status_i ) begin
        if ( rx1_status != `eR_INIT ) begin
            rx1_node_pos <= 0;
            rx1_c_s <= 0;
        end
        rx1_status <= `eR_INIT;
    end

    if (  rx1_clk_reset_cmd ) begin
        rx1_c_s <= {1'b1, `CMD_NOP};
    end

    if ( rx1_dv ) begin
        rx1_nb_bytes <= rx1_nb_bytes + 1;
        rx1_parity_ok <= rx1_parity_ok_c;

        if (( NODE_POS_OFFSET == rx1_nb_bytes ) && rx1_parity_ok_c ) begin
            rx1_node_pos[6:0] <= rx1_d[6:0];
            rx1_node_pos_carry <= rx1_node_pos_c[7];
            if ( rx1_node_pos_inc ) begin
                rx10_d_i <= set_parity( rx1_node_pos_c[6:0] );
            end
        end

        if ((( NODE_POS_OFFSET + 1 ) == rx1_nb_bytes ) && rx1_parity_ok_c && rx1_parity_ok ) begin
            rx1_node_pos[12:7] <= rx1_d[5:0];
            if ( rx1_node_pos_inc ) begin
                rx10_d_i <= set_parity( {rx1_d[6], ( rx1_node_pos_carry ? rx1_node_pos_c[5:0] : rx1_d[5:0] )} );
            end
        end

        if ((( NODE_POS_OFFSET + 2 ) == rx1_nb_bytes ) && rx1_parity_ok_c ) begin
            if ( rx1_init ) begin
                if ( !rx1_delay_set ) begin // Disable clk_sync_set_cmd!
                    rx10_d_i <= set_parity( {rx1_d[6:3], 1'b0, rx1_d[1:0]} ); // Set even partity
                end
            end
        end

        if ((( NODE_POS_OFFSET + 3 ) == rx1_nb_bytes ) && rx1_parity_ok_c && rx1_parity_ok ) begin
            rx1_c_s <= {rx1_d[6:0], rx11_d_i[6:0]};
            if ( rx1_init ) begin
                rx11_d_i <= set_parity( {1'b0, rx1_d[5:0]} ); // Reset command/status bit
            end
        end

        if (( NODE_POS_OFFSET + 4 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd && rx1_parity_ok_c ) begin
                if ( rx1_init ) begin
                    rx1_delay[6:0] <= rx1_d[6:0];
                end
                if ( rx1_delay_set ) begin
                    rx10_d_i <= set_parity( rx1_delay_c[6:0] );
                end
            end
            if ( rx1_mclk_status ) begin
                rx1_c_s <= {1'b0, `CMD_NOP};
            end
        end

        if (( NODE_POS_OFFSET + 5 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    if ( rx1_init ) begin
                        rx1_delay[13:7] <= rx1_d[6:0];
                    end
                    if ( rx1_delay_set ) begin
                        rx10_d_i <= set_parity( rx1_delay_c[13:7] );
                    end
                    rx1_parity_ok <= 1;
                end
            end
        end

        if (( NODE_POS_OFFSET + 6 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    if ( rx1_init ) begin
                        rx1_delay[20:14] <= rx1_d[6:0];
                    end
                    if ( rx1_delay_set ) begin
                        rx10_d_i <= set_parity( rx1_delay_c[20:14] );
                    end
                    rx1_parity_ok <= 1;
                end
            end
        end

        if (( NODE_POS_OFFSET + 7 ) == rx1_nb_bytes ) begin
            if ( rx1_clk_sync_set_cmd ) begin
                rx1_parity_ok <= 0;
                if ( rx1_parity_ok_c && rx1_parity_ok ) begin
                    if ( rx1_init ) begin
                        rx1_delay[27:21] <= rx1_d[6:0];
                        // Start sending clk_sync_set_cmd to next node when
                        // R1 node delay TX1->RX1 has been determined!
                        rx1_delay_set <= |delay_rx10_count;
                    end
                    if ( rx1_delay_set ) begin
                        rx10_d_i <= set_parity( rx1_delay_c[27:21] );
                    end
                    rx1_parity_ok <= 1;
                end
            end
        end

        if ( rx1_ch_dr ) begin
            tx1_ch_d <= rx1_d;
            if ( rx1_ch_dv ) begin
                rx10_d_i <= rx1_ch_d;
            end
        end
    end
    else begin
        rx1_nb_bytes <= 0;
        rx11_d_i <= 0;

        if ( `eR_PRE_INIT == rx1_status_i ) begin
          rx1_status <= `eR_PRE_INIT;
        end

        if ( rx1_init && rx1_delay_set ) begin
            rx1_status <= `eR_WAIT; // CLK_SYNC_SET command received!
        end

        if ( rx1_wait && rx0_cmd_nop ) begin
            rx1_status <= `eR_READY;
        end

        rx1_reset <= rx1_reset || ring_reset_cmd;
    end

    if (( rx1_dv_i && !tx1_dr ) || rx1_error ) begin
        // This is not allowed!
        rx1_error <= 1;
    end

    if ( delay_count[10] ) begin // ~10us delay counting passed!
        rx1_status <= `eR_NO_RR; // Redundant ring broken
    end

    if ( !rst_n || ( rx1_reset && !rx1_dv && !ring_reset_cmd )) begin
        rx1_status <= `eR_IDLE;
        rx1_nb_bytes <= 0;
        rx11_d_i <= 0;
        rx10_d_i <= 0;
        rx1_dv_i <= 0;
        rx1_delay_set <= 0;
        rx1_c_s <= 0;
        rx1_reset <= 0;
    end
end // rx1_process

// TX->RX->FPGA->TX->RX. To determine the propagation delay, the TX->RX delays
// should be divided by two, but the internal FPGA RX->TX copy clock cycle
// should not. Therefore the clocked delay calculation has an offset.
localparam CLK_DELAY_OFFSET = 8;
localparam MCLK_DELTA_OK_LSB = 9;

reg [1:0] rx0_clk_i = 0;
reg [1:0] rx1_clk_i = 0;
reg [1:0] tx0_clk_i = 0;
reg [1:0] tx1_clk_i = 0;
reg random_i = 0;
reg delay_count_en = 0;
reg [4:0]  delay_nb_samples = 0;
wire delay_rx01_count_zero;
wire delay_rx10_count_zero;
wire [9:0] clk_delay_rx0_offset;
wire [9:0] clk_delay_rx1_offset;
reg rx0_rr_request = 0;
reg rx1_rr_request = 0;
reg [67:0] rx0_clk_count = 0;
reg [63:0] rx0_mclk_count = 0;
reg  [4:0] rx0_clk_adjust = CLK_10NS;
wire signed [27:0] rx0_mclk_delta;
wire rx0_mclk_delta_p_ok;
wire rx0_mclk_delta_n_ok;
reg [67:0] rx1_clk_count = 0;
reg [63:0] rx1_mclk_count = 0;
reg  [4:0] rx1_clk_adjust = CLK_10NS;
wire signed [27:0] rx1_mclk_delta;
wire rx1_mclk_delta_p_ok;
wire rx1_mclk_delta_n_ok;

assign delay_rx01_count_zero = ( 0 == delay_rx01_count );
assign delay_rx10_count_zero = ( 0 == delay_rx10_count );
assign clk_delay_rx0_offset = ( CLK_DELAY_OFFSET << rx0_c_s[1:0] );
assign clk_delay_rx1_offset = ( CLK_DELAY_OFFSET << rx1_c_s[1:0] );

assign rx0_mclk_delta = ( rx0_mclk_status ? $signed( {1'b0, {rx0_mclk_count[26:10],
    rx0_c_s[9:0]}} ) : $signed( {1'b0, {rx0_mclk_count[26:0]}} )) - $signed( {1'b0, rx0_clk_count[30:4]} );
assign rx0_mclk_delta_p_ok = !( |rx0_mclk_delta[27:MCLK_DELTA_OK_LSB] );
assign rx0_mclk_delta_n_ok = &rx0_mclk_delta[27:MCLK_DELTA_OK_LSB];
assign rx0_rt_clk_count = rx0_clk_count + rx0_delay + CLK_SYNC_OFFSET;

assign rx1_mclk_delta = ( rx1_mclk_status ? $signed( {1'b0, {rx1_mclk_count[26:10],
    rx1_c_s[9:0]}} ) : $signed( {1'b0, {rx1_mclk_count[26:0]}} )) - $signed( {1'b0, rx1_clk_count[30:4]} );
assign rx1_mclk_delta_p_ok = !( |rx1_mclk_delta[27:MCLK_DELTA_OK_LSB] );
assign rx1_mclk_delta_n_ok = &rx1_mclk_delta[27:MCLK_DELTA_OK_LSB];
assign rx1_rt_clk_count = rx1_clk_count + rx1_delay + CLK_SYNC_OFFSET;

/*============================================================================*/
always @(posedge clk) begin : handle_ports
/*============================================================================*/
    rx0_clk_i <= { rx0_clk_i[0], rx0_clk };
    rx1_clk_i <= { rx1_clk_i[0], rx1_clk };
    tx0_clk_i <= { tx0_clk_i[0], tx0_clk };
    tx1_clk_i <= { tx1_clk_i[0], tx1_clk };
    // Semi random trigger for clock adjustment
    random_i  <= (( rx0_clk_count[11:4] == random_out ) || ( rx1_clk_count[11:4] == random_out ));

    if ( rx0_status_i == rx0_status ) begin
        rx0_status_i <= `eR_IDLE;
    end
    if ( rx1_status_i == rx1_status ) begin
        rx1_status_i <= `eR_IDLE;
    end

    if ( delay_count_en ) begin
        delay_count <= delay_count + 1;
    end

    if ( !rx0_rr_request && !rx1_rr_request ) begin
        if ( rx0_ring_reset_cmd ) begin
            rx0_rr_request <= 1; // Ring reset request
        end if ( rx1_ring_reset_cmd ) begin
            rx1_rr_request <= 1;
        end
    end

    if ( rx0_idle && rx1_idle && !ring_reset_cmd ) begin // eR_IDLE status
        if (( `eR_IDLE == rx0_status_i ) && ( 2'b10 == rx0_clk_i )) begin
            clk00_en <= 0; // Disable when clk low, next cycle!
            clk01_en <= 0;
            dv00_en <= 0;
            dv01_en <= 0;
        end
        if (( `eR_IDLE == rx1_status_i ) && ( 2'b10 == rx1_clk_i )) begin
            clk11_en <= 0; // Disable when clk low, next cycle!
            clk10_en <= 0;
            dv11_en <= 0;
            dv10_en <= 0;
        end
        if ( rx0_dv && !rx1_rr_request ) begin
            if ( 2'b10 == rx0_clk_i ) begin
                clk00_en <= 1; // Enable when clk low, next cycle!
                clk01_en <= 1;
                dv00_en <= 1;
                dv01_en <= 1;
                rx0_status_i <= `eR_INIT;
                rx0_rr_request <= 0;
            end
        end else if ( rx1_dv && !rx0_rr_request ) begin
            if ( 2'b10 == rx1_clk_i ) begin
                clk11_en <= 1; // Enable when clk low, next cycle!
                clk10_en <= 1;
                dv11_en <= 1;
                dv10_en <= 1;
                rx1_status_i <= `eR_INIT;
                rx1_rr_request <= 0;
            end
        end
        delay_nb_samples <= 0;
        delay_count_en <= 0;
        delay_count <= 0;
        delay_rx01_count <= 0;
        delay_rx10_count <= 0;
    end

    if ( rx0_wait && !rx1_pre_init ) begin
        if ( 2'b10 == rx0_clk_i ) begin
            clk00_en <= 0; // Disable when clk low, next cycle!
            dv00_en <= 0;
        end
        if ( 2'b10 == rx1_clk_i ) begin
            clk10_en <= 1; // Enable when clk low, next cycle!
        end
        if ( clk10_en && !( rx1_dv || rx1_dv_i )) begin
            dv10_en <= 1; // Enable dv when RX1 idle/wait
            if ( rx1_idle ) begin
                rx1_status_i <= `eR_PRE_INIT;
            end
        end
    end

    if ( rx0_ready && rx1_pre_init ) begin
        if ( !( rx1_dv || rx1_dv_i )) begin
            if ( !tx1_dv && ( 2'b10 == rx0_clk_i )) begin
                clk01_en <= 0; // Disable when clk low, next cycle!
                dv01_en <= 0;
            end
            if ( !clk01_en && ( 2'b10 == rx1_clk_i )) begin
                clk11_en <= 1; // Enable when clk low, next cycle!
                clk10_en <= 1;
                dv11_en <= 1;
                dv10_en <= 1;
                rx1_status_i <= `eR_INIT;
                delay_nb_samples <= 0;
                delay_count_en <= 0; // Disable delay counting
                delay_count <= 0;
            end
        end
    end

    if ( rx1_wait && !rx0_pre_init ) begin
        if ( 2'b10 == rx1_clk_i ) begin
            clk11_en <= 0; // Disable when clk low, next cycle!
            dv11_en <= 0;
        end
        if ( 2'b10 == rx0_clk_i ) begin
            clk01_en <= 1; // Enable when clk low, next cycle!
        end
        if ( clk01_en && !( rx0_dv || rx0_dv_i )) begin
            dv01_en <= 1; // Enable dv when RX0 idle/wait
            if ( rx0_idle ) begin
                rx0_status_i <= `eR_PRE_INIT;
            end
        end
    end

    if ( rx1_ready && rx0_pre_init ) begin
        if ( !( rx0_dv || rx0_dv_i ) ) begin
            if ( !tx0_dv && ( 2'b10 == rx1_clk_i )) begin
                clk10_en <= 0; // Disable when clk low, next cycle!
                dv10_en <= 0;
            end
            if ( !clk10_en && ( 2'b10 == rx0_clk_i )) begin
                clk00_en <= 1; // Enable when clk low, next cycle!
                clk01_en <= 1;
                dv00_en <= 1;
                dv01_en <= 1;
                rx0_status_i <= `eR_INIT;
                delay_nb_samples <= 0;
                delay_count_en <= 0; // Disable delay counting
                delay_count <= 0;
            end
        end
    end

    if ( rx0_ready && rx1_ready ) begin
        delay_count_en <= 1; // Enable delay counting to detect broken ring
        if ( rx0_dv && rx1_dv ) begin
            delay_count_en <= 0; // Disable delay counting
            delay_count <= 0; // Reset delay counter
        end
    end

    if ( rx0_init && rx0_clk_sync_cmd && delay_rx01_count_zero ) begin
        if (( 2'b01 == tx1_clk_i ) && tx1_dv && !rx1_dv ) begin
            delay_count_en <= 1; // Start counting when delay has not been set yet
        end
        if (( 2'b01 == rx1_clk_i ) && rx1_dv ) begin
            if ( delay_count_en ) begin
                delay_nb_samples <= delay_nb_samples + 1;
                delay_count_en <= 0; // Disable delay counting
            end
        end
        if ( delay_count ) begin
            if (( 1 << rx0_c_s[1:0] ) == delay_nb_samples ) begin
                delay_rx01_count <= {delay_count, 4'h0} >> ( rx0_c_s[1:0] + 1 );
                delay_count <= 0; // Reset delay counter
            end
        end else begin
            delay_count <= clk_delay_rx0_offset;
        end
    end

    if ( rx1_init && rx1_clk_sync_cmd && delay_rx10_count_zero ) begin
        if (( 2'b01 == tx0_clk_i ) && tx0_dv && !rx0_dv ) begin
            delay_count_en <= 1; // Start counting when delay has not been set yet
        end
        if (( 2'b01 == rx0_clk_i ) && rx0_dv ) begin
            if ( delay_count_en ) begin
                delay_nb_samples <= delay_nb_samples + 1;
                delay_count_en <= 0; // Disable delay counting
            end
        end
        if ( delay_count ) begin
            if (( 1 << rx1_c_s[1:0] ) == delay_nb_samples ) begin
                delay_rx10_count <= {delay_count, 4'h0} >> ( rx1_c_s[1:0] + 1 );
                delay_count <= 0; // Reset delay counter
            end
        end else begin
            delay_count <= clk_delay_rx1_offset;
        end
    end

    if ( delay_count[10] ) begin // Redundant ring broken
        delay_count_en <= 0; // Disable delay counting
    end

    rx0_mclk_count <= rx0_mclk_count + 1;
    if ( rx0_ready && rx1_ready && ( CHANNEL_OFFSET  == rx0_nb_bytes ) && ( 2'b01 == rx0_clk_i )) begin
        // Check for master clock count status at CLK_SYNC_OFFSET, ignore delta wraparounds
        if ( rx0_mclk_status && ( rx0_mclk_delta_p_ok || rx0_mclk_delta_n_ok )) begin
            rx0_mclk_count[9:0] <= rx0_c_s[9:0];
        end
    end

    rx0_clk_adjust_fast <= 0;
    if ( rx0_ready ) begin
        if ( rx0_mclk_delta_p_ok ) begin
            rx0_clk_adjust <= CLK_10NS + 1;
            if ( |rx0_mclk_delta[MCLK_DELTA_OK_LSB-1:3] ) begin // Fast adjust!
                rx0_clk_adjust <= CLK_10NS + 7;
                rx0_clk_adjust_fast <= 1;
            end
        end
        if ( rx0_mclk_delta_n_ok ) begin
            rx0_clk_adjust <= CLK_10NS - 1;
            if ( !( &rx0_mclk_delta[MCLK_DELTA_OK_LSB-1:3] )) begin // Fast adjust!
                rx0_clk_adjust <= CLK_10NS - 7;
            end
        end
        if ( 0 == rx0_mclk_delta ) begin
            rx0_clk_adjust <= CLK_10NS;
        end
    end

    rx0_clk_count <= rx0_clk_count + ( random_i ? rx0_clk_adjust : CLK_10NS );
    if ( rx0_clk_reset_cmd && ( 2'b01 == rx0_clk_i )) begin
        rx0_clk_count <= 0;
        rx0_mclk_count <= 0;
    end

    rx1_mclk_count <= rx1_mclk_count + 1;
    if ( rx0_ready && rx1_ready && ( CHANNEL_OFFSET == rx1_nb_bytes ) && ( 2'b01 == rx1_clk_i )) begin
        // Check for master clock count status at CLK_SYNC_OFFSET, ignore delta wrap arounds!
        if ( rx1_mclk_status && ( rx1_mclk_delta_p_ok || rx1_mclk_delta_n_ok )) begin
            rx1_mclk_count[9:0] <= rx1_c_s[9:0];
        end
    end

    rx1_clk_adjust_fast <= 0;
    if ( rx1_ready ) begin
        if ( rx1_mclk_delta_p_ok ) begin
            rx1_clk_adjust <= CLK_10NS + 1;
            if ( |rx1_mclk_delta[MCLK_DELTA_OK_LSB-1:3] ) begin // Fast adjust!
                rx1_clk_adjust <= CLK_10NS + 7;
            end
        end
        if ( rx1_mclk_delta_n_ok ) begin
            rx1_clk_adjust <= CLK_10NS - 1;
            if ( !( &rx1_mclk_delta[MCLK_DELTA_OK_LSB-1:3] )) begin // Fast adjust!
                rx1_clk_adjust <= CLK_10NS - 7;
                rx1_clk_adjust_fast <= 1;
            end
        end
        if ( 0 == rx1_mclk_delta ) begin
            rx1_clk_adjust <= CLK_10NS;
        end
    end

    rx1_clk_count <= rx1_clk_count + ( random_i ? rx1_clk_adjust : CLK_10NS );
    if ( rx1_clk_reset_cmd && ( 2'b01 == rx1_clk_i )) begin
        rx1_clk_count <= 0;
        rx1_mclk_count <= 0;
    end

    if ( !rst_n ) begin
        rx0_clk_i <= 0;
        rx1_clk_i <= 0;
        tx0_clk_i <= 0;
        tx1_clk_i <= 0;
        random_i <= 0;
        rx0_status_i <= `eR_IDLE;
        rx1_status_i <= `eR_IDLE;
        clk00_en <= 0;
        clk01_en <= 0;
        dv00_en <= 0;
        dv01_en <= 0;
        clk11_en <= 0;
        clk10_en <= 0;
        dv11_en <= 0;
        dv10_en <= 0;
        /*-----------------------*/
        rx0_clk_count <= 0;
        rx0_mclk_count <= 0;
        rx0_clk_adjust <= CLK_10NS;
        rx1_clk_adjust_fast <= 0;
        rx1_clk_count <= 0;
        rx1_mclk_count <= 0;
        rx1_clk_adjust <= CLK_10NS;
        rx1_clk_adjust_fast <= 0;
    end
end // handle_ports

assign tx0_clk = ( rx0_clk & clk00_en ) | ( rx1_clk & clk10_en );
assign tx1_clk = ( rx1_clk & clk11_en ) | ( rx0_clk & clk01_en );
assign tx0_d = ( rx00_d_i & { 8{ clk00_en }} ) | ( rx10_d_i & { 8{ clk10_en }} );
assign tx0_dv = ( rx0_dv_i & dv00_en ) | ( rx1_dv_i & dv10_en );
assign tx1_d = ( rx11_d_i & { 8{ clk11_en }} ) | ( rx01_d_i & { 8{ clk01_en }} );
assign tx1_dv = ( rx1_dv_i & dv11_en ) | ( rx0_dv_i & dv01_en );
assign tx0_err = rx0_error | rx0_err;
assign tx1_err = rx1_error | rx1_err;

endmodule // sr2cb_s
