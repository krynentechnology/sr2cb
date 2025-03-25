# ECP5
<p>SR2CB protocol HW setup for Lattice Semiconductor&reg; ECP5&#8482; Development Board with cross-wired RJ-45 cable.</p>

<img src="ecp5_100Mb_wired.jpg" width=800>

<p>The Lattice Semiconductor&reg; ECP5&#8482; Development Board has a 1Gb/s Ethernet PHY (Marvell 88E1512) and should be setup for 100Mb/s with a cross-wired RJ-45 cable via a terminal connection. The SR2CB FPGA logic provides an UART/TTL terminal connection via the ECP5&#8482; Development Board FDTI USB port. The ECP5&#8482; Versa Development Board has from factory its FDTI FT2232H EEPROM not correctly configured for UART use. Reconfigure EEPROM by FT_PROG utility from FDTI - "Scan and parse". Set "Hardware Specific" - port B to UART and VCP (Virtual COM Port) and reprogram FT2232H EEPROM.</p>

<img src="FT2232H_ecp5versa_fix.png" width=800>

<p>The terminal commands "00A100" and "20A100" (write 0xA100 to PHY1 and PHY2 register 0 - Copper Control) forces the PHYs to 100Mb full duplex. Force link up for a continuous PHYs RXCLK with terminal commands "100400" and "300400" (write 0x0400 to PHY1 and PHY2 register 16 - 0x10/0x30). Read PHYs register 17 - 0x11/0x31 (Copper Specific Status Register 1 - 100Mbps, full duplex, auto-negotiation resolved and (copper) link-up). The terminal command "803" sets the PHYs link up bits in the SR2CB FPGA logic and the SR2CB master starts sending SR2CB frames.</p>

<img src="ecp5_100Mb_terminal.png" width=600>
