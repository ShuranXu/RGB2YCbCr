quit -sim
if {[file exists work]} {
	vdel -lib work -all;
}
if {![file exists work]} {
	vlib work;
}

vlog RGB2YCbCr.v
vlog RGB2YCbCr_tb.sv
vsim RGB2YCbCr_tb 

add wave -unsigned /RGB2YCbCr_tb/*

run 1000ns
