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
 *  Description:
 *
 *  Sends SR2CB master TX PHY preamble, SFD and waits IPG bytes.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module sr2cb_m_phy_pre (
/*============================================================================*/
    input  wire       clk,
    input  wire       rst_n, // Synchronous reset, high when clk is stable!
    input  wire [7:0] rx_d,  // Byte read data
    input  wire       rx_dv, // Read data valid
    output wire       rx_dr, // Ready for data
    output wire [7:0] tx_d,  // Byte write data
    output wire       tx_dv  // Write data valid
    );

localparam PREAMBLE_SFD = { 56'h55555555555555, 8'hD5 };
localparam IPG_BYTES    = 5;
localparam FIFO_SIZE    = 8;

reg [7:0] fifo [0:FIFO_SIZE-1];
reg [3:0] fifo_count;
reg [2:0] ipg_count;

wire fifo_empty;
assign fifo_empty = ( 0 == fifo_count );
wire ipg_done;
assign ipg_done = ( 0 == ipg_count );

/*============================================================================*/
initial begin
/*============================================================================*/
    fifo_count = 0;
    ipg_count  = 0;
    { fifo[ 7 ],
      fifo[ 6 ],
      fifo[ 5 ],
      fifo[ 4 ],
      fifo[ 3 ],
      fifo[ 2 ],
      fifo[ 1 ],
      fifo[ 0 ] } = PREAMBLE_SFD;
end

/*============================================================================*/
always @(posedge clk) begin : phy_tx_fifo_process
/*============================================================================*/
    fifo_count <= 0;
    { fifo[ 7 ],
      fifo[ 6 ],
      fifo[ 5 ],
      fifo[ 4 ],
      fifo[ 3 ],
      fifo[ 2 ],
      fifo[ 1 ],
      fifo[ 0 ] } <= PREAMBLE_SFD;

    if ( rst_n ) begin
        if (( rx_dv && rx_dr ) || !fifo_empty ) begin
            if ( !fifo_empty ) begin
                fifo_count <= fifo_count - 1;
            end

            { fifo[ 7 ], fifo[ 6 ], fifo[ 5 ], fifo[ 4 ], fifo[ 3 ], fifo[ 2 ], fifo[ 1 ], fifo[ 0 ] } <=
                { fifo[ 6 ], fifo[ 5 ], fifo[ 4 ], fifo[ 3 ], fifo[ 2 ], fifo[ 1 ], fifo[ 0 ], rx_d };

            ipg_count <= IPG_BYTES - 1; // Minus 1 to set rx_dr high for rx_dv
            if ( rx_dv ) begin
                fifo_count <= FIFO_SIZE;
            end
        end
        else if ( !ipg_done ) begin
            ipg_count <= ipg_count - 1;
        end
    end
end

assign rx_dr = ( fifo_empty & ipg_done ) | ( rx_dv & ~ipg_done );
assign tx_d  = fifo[ 7 ];
assign tx_dv = rx_dv | ~fifo_empty;

endmodule
