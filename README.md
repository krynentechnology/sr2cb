# SR2CB
<p>The Synchronous Redundant Ring Channel Bus (<i>S-R-square-C-Bus</i>) is a data bus with a open ring topology where a data <i>channel</i> is constructed from successive frames fixed bit/bits/byte/word/dword/qword/etc. positions. The
SR2CB network protocol supports <i>synchronous</i> operation by means of a distributed clock mechanism. Each ring node has two full duplex (TX/RX) hardware ports.</p>

<p>The physical interface (<i>layer</i>) between SR2CB nodes is based on 1000BASE-T, 100BASE-TX, RS-485 or LVDS. 1000BASE-T and 100BASE-TX PHYs are also common for the ethernet network physical layer but not bound to transmit solely ethernet frames. The SR2CB frames are continuously transmitted by the ring nodes clockwise and counterclockwise. Slave nodes retransmit those SR2CB frames after receipt and insert or extract channel data 'on the fly'. Within a SR2CB master/slave ring the single master node starts the redundant ring initialization and transmits the SR2CB frames. Master nodes do not pass SR2CB frames around except for a broken redundant ring (<i>single point of failure</i>) or when the redundant ring is exclusivly build from master nodes.</p>

<p>SR2CB (master) protocol HW setup for <a href="c10lp/README.md">Intel&reg; Cyclone&reg; 10 LP Evaluation Kit</a> and <a href="ecp5/README.md">Lattice Semiconductor&reg; ECP5&#8482; Development Board</a>.</p>

<img src="SR2CB M-S PHY.png" width=800>
