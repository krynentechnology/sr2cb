# Create clocks
# create_clock -name CLK_125M -period "125MHz" [get_ports CLK0_125M]
create_clock -name CLK_100M -period "100MHz" [get_ports CLK1_100M]
# create_clock -name CLK_50M -period "50MHz" [get_ports CLK2_50M]
create_clock -name CLK_25M -period "25MHz" [get_ports PHY_RX_CLK]
# Setup time
set_false_path -from * -to [get_ports PHY_MDC]
set_false_path -from * -to [get_ports PHY_MDIO]
set_false_path -from * -to [get_ports PHY_MDINT]
set_false_path -from * -to [get_ports LED[*]]
set_false_path -from * -to [get_ports UART_RX]
set_false_path -from * -to [get_ports UART_TX]
