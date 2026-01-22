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
 */
`ifndef SR2CB_DEF
`define SR2CB_DEF
// ---- SR2CB protocol command symbol definitions ----
`define MAX_NB_NODES   10 // 8192
`define CMD_NOP        13'h0000 // Command "no operation" - do nothing
`define CLK_SYNC_0     13'h0008 // 1 delay sample (single delay measurement)
`define CLK_SYNC_SET_0 13'h000C // 1 delay sample, CLK_SYNC_0 + bit 2 set
`define CLK_SYNC_1     13'h0009 // 2 delay samples
`define CLK_SYNC_SET_1 13'h000D // 2 delay samples, CLK_SYNC_1 + bit 2 set
`define CLK_SYNC_2     13'h000A // 4 delay samples
`define CLK_SYNC_SET_2 13'h000E // 4 delay samples, CLK_SYNC_2 + bit 2 set
`define CLK_SYNC_3     13'h000B // 8 delay samples
`define CLK_SYNC_SET_3 13'h000F // 8 delay samples, CLK_SYNC_3 + bit 2 set
`define CLK_RESET      13'h0010 // Clock reset
`define RING_RESET     13'h1FFF // Ring reset to eR_IDLE
// ---- SR2CB protocol status symbol definitions ----
`define MASTER_CLK_10L 13'h0400 // Lowest 10 bits (0-9) of master clock value
`define MASTER_CLK_10N 13'h0800 // Next 10 bits (10-20) of master clock value
                                // Bits [12:10] status type, 0,1 == MASTER_CLK
`define TIMER_TICK_1MS 13'h1000
`define CW_RDIR        1'b0     // Clockwise ring direction
`define CCW_RDIR       1'b1     // Counterclockwise ring direction
// ---- Node ring status enum ----
`define eR_IDLE     3'b000
`define eR_PRE_INIT 3'b001
`define eR_INIT     3'b010
`define eR_WAIT     3'b011
`define eR_READY    3'b100
`define eR_NO_RR    3'b111 // Broken redundant ring
//
`endif
