# digital-design-peak-detector
Implement a peak detector design in a FPGA.

for details can read https://seis.bristol.ac.uk/~sy13201/digital_design/ECAD/A2_index.htm

Designed and implemented a peak detection system with modules, including the peak detector, data source, and communication links based on UART.
The peak detector task involves processing user-typed words in the terminal, identifying the peak byte, and returning it along with the three bytes preceding and following it. The byte's interpretation is based on signed or unsigned formats determined by the group number. Implemented on the CMOD A7 board with an Artix 7 device running on a 100 MHz system clock, if multiple peaks occur, the first one is retained.

For test and verification details, please see the report.
