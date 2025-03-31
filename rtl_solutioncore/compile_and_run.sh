#!/bin/bash

iverilog -g2012 -o RGB2YCbCr_tb.vvp RGB2YCbCr_tb.sv
vvp -n RGB2YCbCr_tb.vvp
rm RGB2YCbCr_tb.vvp