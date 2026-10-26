# run.tcl - program the Zybo Z7-10 and run one of the Lab 4 test programs (no Vivado/Vitis project needed).
# Usage (from this folder, board plugged in, power ON):
#   xsdb run.tcl bram     -> multiplier IP + BRAM test (32 products, prints my name)
#   xsdb run.tcl fifo     -> sc_fifo_axi IP test (push/pop/status/config)
# Output appears on the board's UART: COM port, 115200 baud.
# These are the same steps the Vitis "Run" button does. Drafted with Claude (Anthropic).
set here [file dirname [file normalize [info script]]]
set which [expr {[llength $argv] ? [lindex $argv 0] : "bram"}]
set elf [expr {$which eq "fifo" ? "$here/fifo_app.elf" : "$here/bram_app.elf"}]
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 3000
targets -set -nocase -filter {name =~ "xc7z010*"}
fpga -file $here/mult_bd_AR_wrapper.bit
targets -set -nocase -filter {name =~ "APU*"}
loadhw -hw $here/mult_bd_AR_wrapper.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
source $here/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
rst -processor
dow $elf
configparams force-mem-access 0
con
puts "Running $elf - watch the serial terminal (115200 baud)."
