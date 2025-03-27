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
 *               Development Board test bench
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
// `include "ecp5_sr2cb.v"
`include "../rtl/sr2cb_def.v"

/*============================================================================*/
module ecp5_sr2cb_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

reg rx1_clk = 0;
reg [3:0] rx1_d = 0;
reg rx1_ctrl = 0;
wire tx1_clk;
wire [3:0] tx1_d;
wire tx1_ctrl;
reg rx2_clk = 0;
reg [3:0] rx2_d = 0;
reg rx2_ctrl = 0;
wire tx2_clk;
wire [3:0] tx2_d;
wire tx2_ctrl;
wire uart_rx;
wire uart_tx;

/*============================================================================*/
ecp5_sr2cb ecp5_sr2cb_dut (
/*============================================================================*/
    .CLK(clk),
    .ARST_N(rst_n),
    .PHY1_RST_N(),
    .PHY1_MDC(),
    .PHY1_MDIO(),
    .PHY1_RGMII_RXCLK(rx1_clk),
    .PHY1_RGMII_RXD(rx1_d),
    .PHY1_RGMII_RXCTL(rx1_ctrl),
    .PHY1_RGMII_TXCLK(tx1_clk),
    .PHY1_RGMII_TXD(tx1_d),
    .PHY1_RGMII_TXCTL(tx1_ctrl),
    .PHY1_CONFIG(),
    .PHY2_RST_N(),
    .PHY2_MDC(),
    .PHY2_MDIO(),
    .PHY2_RGMII_RXCLK(rx2_clk),
    .PHY2_RGMII_RXD(rx2_d),
    .PHY2_RGMII_RXCTL(rx2_ctrl),
    .PHY2_RGMII_TXCLK(tx2_clk),
    .PHY2_RGMII_TXD(tx2_d),
    .PHY2_RGMII_TXCTL(tx2_ctrl),
    .PHY2_CONFIG(),
    .UART_RX(uart_rx),
    .UART_TX(uart_tx),
    .LED(),
    .DP(),
    .SEG(),
    .DIP_SW()
    );

localparam NR_BITS = 8;

wire [7:0] uart_rx_d;
wire uart_rx_dv;
reg  [7:0] rx_data = 0;
reg  [7:0] uart_tx_d = 0;
reg  uart_tx_dv = 0;
wire uart_tx_dr;

uart #(
    .CLK_FREQ( 100E6 ), // 100Mhz
    .BAUD_RATE( 115.2E3 ), // 115K2
    .NR_BITS( NR_BITS ),
    .PARITY( "NONE" ),
    .STOP_BITS( 1 ))
uart1 (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart_rx_d),
    .uart_rx_dv(uart_rx_dv),
    .parity_ok(),
    .uart_tx_d(uart_tx_d),
    .uart_tx_dv(uart_tx_dv),
    .uart_tx_dr(uart_tx_dr),
    .uart_rx(uart_tx),
    .uart_tx(uart_rx)
    );

localparam NIBBLE_CTRL_FIFO = 10;

reg [3:0] tx1rx2_nibble_delay[0:NIBBLE_CTRL_FIFO-1];
reg [NIBBLE_CTRL_FIFO-1:0]tx1rx2_ctrl_delay = 0;
reg [3:0] tx2rx1_nibble_delay[0:NIBBLE_CTRL_FIFO-1];
reg [NIBBLE_CTRL_FIFO-1:0]tx2rx1_ctrl_delay = 0;

integer n;
/*============================================================================*/
always @(posedge tx1_clk) begin : tx1rx2_fifo
/*============================================================================*/
    for ( n = ( NIBBLE_CTRL_FIFO - 1 ); n > 0; n = n - 1 ) begin
        tx1rx2_nibble_delay[n] <= tx1rx2_nibble_delay[n-1];
        tx1rx2_ctrl_delay[n] <= tx1rx2_ctrl_delay[n-1];
    end
    tx1rx2_nibble_delay[0] <= tx1_d;
    tx1rx2_ctrl_delay[0] <= tx1_ctrl;
end // tx1rx2_fifo

integer m;
/*============================================================================*/
always @(posedge tx2_clk) begin : tx2rx1_fifo
/*============================================================================*/
    for ( m = ( NIBBLE_CTRL_FIFO - 1 ); m > 0; m = m - 1 ) begin
        tx2rx1_nibble_delay[m] <= tx2rx1_nibble_delay[m-1];
        tx2rx1_ctrl_delay[m] <= tx2rx1_ctrl_delay[m-1];
    end
    tx2rx1_nibble_delay[0] <= tx2_d;
    tx2rx1_ctrl_delay[0] <= tx2_ctrl;
end // tx2rx1_fifo

/*============================================================================*/
always @(posedge rx1_clk) begin : rx1_synchronize
/*============================================================================*/
    rx1_d <= tx2rx1_nibble_delay[NIBBLE_CTRL_FIFO-1];
    rx1_ctrl <= tx2rx1_ctrl_delay[NIBBLE_CTRL_FIFO-1];
end // rx1_synchronize

/*============================================================================*/
always @(posedge rx2_clk) begin : rx2_synchronize
/*============================================================================*/
    rx2_d <= tx1rx2_nibble_delay[NIBBLE_CTRL_FIFO-1];
    rx2_ctrl <= tx1rx2_ctrl_delay[NIBBLE_CTRL_FIFO-1];
end // rx2_synchronize

/*============================================================================*/
always @(posedge clk) begin : rx_data_collect
/*============================================================================*/
    if ( uart_rx_dv ) begin
        rx_data <= uart_rx_d;
    end
end // rx_data_collect

integer j;
/*============================================================================*/
task uart_write( input string uart_i );
/*============================================================================*/
begin
    for ( j = 0; j < uart_i.len(); j = j + 1 ) begin
        wait ( uart_tx_dr );
        wait ( clk ) @( negedge clk );
        uart_tx_d = uart_i[j];
        uart_tx_dv = 1;
        wait ( !uart_tx_dr );
        wait ( clk ) @( negedge clk );
        uart_tx_dv = 0;
    end
end
endtask // uart_write

always #5  clk = ~clk; // 100 MHz clock
always #20.001 rx1_clk = ~rx1_clk; // 25 MHz clock +50ppm
always #19.999 rx2_clk = ~rx2_clk; // 25 MHz clock -50ppm

integer i;
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < NIBBLE_CTRL_FIFO; i = i + 1 ) begin
        tx1rx2_nibble_delay[i] = 0;
        tx2rx1_nibble_delay[i] = 0;
    end
    rst_n = 0;
    ecp5_sr2cb_dut.rx0tx0_link = 0;
    ecp5_sr2cb_dut.rx1tx1_link = 0;
    #100
    $display( "SR2CB ECP5 Versa simulation started" );
    rst_n = 1;
    #100
    // uart_write( "803" );
    ecp5_sr2cb_dut.rx0tx0_link = 1;
    #10
    ecp5_sr2cb_dut.rx1tx1_link = 1;
    $display( "Link up" );
    #100000
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "ecp5_sr2cb_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // ecp5_sr2cb_tb
