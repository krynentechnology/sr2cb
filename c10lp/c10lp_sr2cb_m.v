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
 *  Description: SR2CB (master) protocol HW setup for Cyclone 10 LP Evaluation
 *               Kit
 *
 *  100Mbs (fast ethernet) RJ-45 loopback plug - connect pin 1 (TX+) to 3 (RX+)
 *  and pin 2 (TX-) to 6 (RX-)
 *
 *  C10LP>002100 // Write PHY 00h to force 100Mb full duplex and put 100Mbs
 *               // loopback plug in RJ-45 connector - 100Mbs and linkup LED
 *               // should light
 *  C10LP>17     // Read PHY 17h, should be 0xB000 otherwise write this value
 *  C10LP>B000   // RXCLK is active also when link is down (!), copper data
 *               // flow, RGMII mode
 *  C10LP>18     // Read PHY 18h
 *  C10LP>0009   // Full duplex, 100Mbs
 *  C10LP>401    // Link up
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
`include "../rtl/sr2cb_def.v"

/*============================================================================*/
module c10lp_sr2cb_m (
/*============================================================================*/
    input  wire CLK1_100M, // 100Mhz LVDS clock
    input  wire ARST_N,
    // MaxLinear PHY GPY111 RGMII interface
    output wire PHY_RESETN,
    output wire PHY_MDC,
    inout  wire PHY_MDIO,
    input  wire PHY_MDINT,
    input  wire PHY_RX_CLK,
    input  wire PHY_RX_CTRL,
    input  wire [3:0] PHY_RXD,
    output wire PHY_TX_CLK,
    output wire PHY_TX_CTRL,
    output wire [3:0] PHY_TXD,
    //
    input  wire UART_RX, // TTL J18.3
    output wire UART_TX, // TTL J18.4
    output wire [3:0] LED,
    input  wire [3:0] PB, // Push button
    input  wire [2:0] DIP_SW // Dip switch
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
localparam CHW = clog2( NR_CHANNELS );
localparam NR_BITS = 8;

wire clk;
wire rst_n;
assign clk = CLK1_100M;

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
    .PROMPT( "C10LP>" ),
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
wire mdc;
wire mdio_o;
wire mdio_oe;

phy_mdio #(
    .NR_PHY( 1 ),
    .PREAMBLE( 1 ),
    .TL_BIDIR( 1 ),
    .PARALLEL( 0 ))
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
    .m_mdio_pa(),
    .m_mdio_d(m_mdio_d),
    .m_mdio_dv(m_mdio_dv),
    .mdc(mdc),
    .mdio(),
    .mdio_i(PHY_MDIO),
    .mdio_o(mdio_o),
    .mdio_oe(mdio_oe)
    );

wire rx0_clk;
wire [7:0] rx0_d;
reg  [7:0] rx_data = 0;
wire rx0_dv;
wire rx0_er;
reg rx_error = 0;
wire tx0_clk;
wire [7:0] tx_d;
wire tx_dv;

phy_100Mb #(
    .CFG_MODE( "RGMII" ))
phy_gpy111 (
    .clk(clk),
    .rx_clk(rx0_clk),
    .rx_d(rx0_d),
    .rx_dv(rx0_dv),
    .rx_er(rx0_er),
    .tx_clk(tx0_clk),
    .tx_d(tx_d),
    .tx_dv(tx_dv),
    .phy_rx_clk(PHY_RX_CLK),
    .phy_rxd(PHY_RXD),
    .phy_rgmii_rx_ctrl(PHY_RX_CTRL),
    .phy_mii_rx_dv(),
    .phy_mii_rx_er(),
    .phy_mii_tx_clk(PHY_RX_CLK),
    .phy_rmii_clk(),
    .phy_rgmii_tx_clk(PHY_TX_CLK),
    .phy_txd(PHY_TXD),
    .phy_mii_tx_en(),
    .phy_rgmii_tx_ctrl(PHY_TX_CTRL)
    );

assign PHY_RESETN = rst_n;
assign PHY_MDC = mdc;
assign PHY_MDIO = mdio_oe ? mdio_o : 1'bZ;

wire [7:0] tx0_d;
wire tx0_dv;
wire tx0_dr;
reg  [7:0] tx_u_d = 0;
reg  tx0u_dv = 0;
reg  tx0u_dv_i = 0;

/*============================================================================*/
sr2cb_m_phy_pre phy_pre(
/*============================================================================*/
    .clk(tx0_clk),
    .rst_n(rst_n),
    .rx_d(tx0_dv ? tx0_d : tx_u_d),
    .rx_dv(tx0_dv | tx0u_dv),
    .rx_dr(tx0_dr),
    .tx_d(tx_d),
    .tx_dv(tx_dv)
);

reg  link_up = 0;
wire rx1_clk;
wire [7:0] rx1_d;
wire rx1_dv;
wire [7:0] tx1_d;
wire tx1_dv;
wire rx0_ch_dr;
wire [7:0] tx0_ch_d;
wire [CHW-1:0] rx0_tx0_ch;
wire rx1_ch_dr;
wire [7:0] tx1_ch_d;
wire [CHW-1:0] rx1_tx1_ch;
wire tx0rx0_valid;
wire [12:0] rx0_node_pos;
wire [13:0] rx0_c_s;
wire [2:0] rx0_status;
wire [27:0] rx0_delay;
wire tx1rx1_valid;
wire [12:0] rx1_node_pos;
wire [13:0] rx1_c_s;
wire [2:0] rx1_status;
wire [27:0] rx1_delay;
wire [2:0] tx0_status;
wire [2:0] tx1_status;
wire ring_reset_pending;
wire [63:0] clk_m_count;

/*============================================================================*/
sr2cb_m #( .NR_CHANNELS( NR_CHANNELS )) master_node(
/*============================================================================*/
    .clk(clk),
    .rst_n(rst_n),
    .rx0tx0_link(link_up), // Link up status set by terminal console
    .rx0_loopback(),
    .rx0_clk(rx0_clk),
    .rx0_d(rx0_d),
    .rx0_dv(rx0_dv),
    .rx0_err(1'b0),
    .tx0_clk(),
    .tx0_d(tx0_d),
    .tx0_dv(tx0_dv),
    .tx0_dr(tx0_dr),
    .tx0_err(),
    .rx1tx1_link(link_up), // Link up status set by terminal console
    .rx1_loopback(),
    .rx1_clk(rx1_clk),
    .rx1_d(rx1_d),
    .rx1_dv(rx1_dv),
    .rx1_err(1'b0),
    .tx1_clk(),
    .tx1_d(tx1_d),
    .tx1_dv(tx1_dv),
    .tx1_dr(1'b0),
    .tx1_err(),
    .rx0_ch_d(8'd0),
    .rx0_ch_dv(1'b0),
    .rx0_ch_dr(rx0_ch_dr),
    .tx0_ch_d(tx0_ch_d),
    .rx0_tx0_ch(rx0_tx0_ch),
    .rx1_ch_d(8'b0),
    .rx1_ch_dv(1'b0),
    .rx1_ch_dr(rx1_ch_dr),
    .tx1_ch_d(tx1_ch_d),
    .rx1_tx1_ch(rx1_tx1_ch),
    .tx0rx0_valid(tx0rx0_valid),
    .rx0_node_pos(rx0_node_pos),
    .rx0_c_s(rx0_c_s),
    .rx0_status(rx0_status),
    .rx0_delay(rx0_delay),
    .tx1rx1_valid(tx1rx1_valid),
    .rx1_node_pos(rx1_node_pos),
    .rx1_c_s(rx1_c_s),
    .rx1_status(rx1_status),
    .rx1_delay(rx1_delay),
    .tx0_status(tx0_status),
    .tx0_c_s(13'd0),
    .tx1_status(tx1_status),
    .tx1_c_s(13'd0),
    .ring_reset_pending(ring_reset_pending),
    .clk_count(clk_m_count)
);

wire clk_div2; // 25MHz
wire clk_div4; // 12.5MHz

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
assign LED[0] = clk_count[25]; // Heart beat
assign LED[1] = 1'b1; // Zero == on
assign LED[2] = ~mdc; // MDC activity
assign LED[3] = PHY_MDIO; // MDIO activity


/*============================================================================*/
always @(posedge clk or negedge ARST_N) begin : clock_counter
/*============================================================================*/
    if ( !ARST_N ) begin
        clk_count <= 0;
    end else begin
        clk_count <= clk_count + 1;
    end
end

assign clk_div2 = clk_count[0]; // 50MHz
assign clk_div4 = clk_count[1]; // 25Mhz
// assign mdio_clk = clk_count[2]; // 12.5MHz
// assign mdio_clk = clk_count[3]; // 6.25MHz
// assign mdio_clk = clk_count[4]; // 3.125MHz
// assign mdio_clk = clk_count[5]; // 1.5625MHz
// assign mdio_clk = clk_count[6]; // 781.25kHz
// assign mdio_clk = clk_count[7]; // 390.625kHz
// assign mdio_clk = clk_count[8]; // 195.3125kHz
assign mdio_clk = clk_count[9]; // 97.65625kHz (GPY111 MDC < 100khz!)

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
localparam [7:0] LF = 8'h0A;

/*============================================================================*/
always @(posedge clk) begin : uart_cmd
/*============================================================================*/
    s_mdio_dv <= s_mdio_dv & s_mdio_dr;
    tx0u_dv_i <= tx0u_dv_i & ~( tx0u_dv & tx0u_dv_i );
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
        case ( u_rxd_cmd[7:5] )
        3'b000 : begin // MDIO registers 0x00-0x1F
            if ( 2 == u_rx_count ) begin
                s_mdio_rd <= 1; // Read MDIO
                s_mdio_ra <= u_rxd_cmd[4:0];
                s_mdio_dv <= 1;
            end
            if ( 6 == u_rx_count ) begin
                s_mdio_rd <= 0; // Write MDIO
                s_mdio_ra <= u_rxd_cmd[4:0];
                s_mdio_d <= u_rxd_param;
                s_mdio_dv <= 1;
            end
        end
        3'b001 : begin // PHY RX/TX
            if ( 2 == u_rx_count ) begin
                u_txd <= {rx_error, 7'd0, rx_data};
                u_tx_enable <= 1;
            end
            if ( 4 == u_rx_count ) begin
                tx0u_dv_i <= 1;
                tx_u_d <= u_rxd_param[15:8];
            end
        end
        3'b010 : begin // PHY link up
            if ( 3 == u_rx_count ) begin
                link_up <= u_rxd_param[12];
            end
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
        tx0u_dv_i <= 0;
    end
end // uart_cmd

/*============================================================================*/
always @(posedge rx0_clk) begin : phy_rx_process
/*============================================================================*/
    if ( rx0_dv ) begin
        rx_data <= rx0_d;
        rx_error <= rx0_er;
    end
end

/*============================================================================*/
always @(posedge tx0_clk) begin : phy_tx_process
/*============================================================================*/
    tx0u_dv <= tx0u_dv_i;
end

endmodule // c10lp_sr2cb_m