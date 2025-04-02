/////////////////////////////////////////////////////////////////////
////                                                             ////
////  Testbench for RGB to YCrCb Color Space converter           ////
////                                                             ////
////  Converts RGB values to YCrCB (YUV) values                  ////
////  Y  = 0.299R + 0.587G + 0.114B                              ////
////  Cr = 0.713(R - Y)                                          ////
////  Cb = 0.565(B - Y)                                          ////
////                                                             ////
////  Author: Shuran Xu                                          ////
////                                                             ////
/////////////////////////////////////////////////////////////////////


`timescale 1ns/10ps
`include "RGB2YCbCr.v"
`define clk_period 10

module RGB2YCbCr_tb();

	parameter emargin = 3; // we allow a small error
	parameter debug = 0;
	parameter r_length = 64;
	parameter g_length = 64;
	parameter b_length = 64;

	// variables
	reg clk;
	reg rst;

	reg  [9:0] r [3:0];
	reg  [9:0] g [3:0];
	reg  [9:0] b [3:0];

	wire [9:0] y, cr, cb;

	integer my, mcr, mcb;
	integer iy, icr, icb;

	//
	// module under test
	//

	rgb2ycrcb dut (
		.clk(clk),
		.rst(rst),
		.r(r[0]),
		.g(g[0]),
		.b(b[0]),
		.y(y),
		.cr(cr),
		.cb(cb)
	);

	always #(`clk_period / 2) clk <= ~clk;

	integer r_idx, g_idx, b_idx;

	// testbench starts
	initial
	begin
		clk = 0;
		rst = 1;
	
		r[0] = 0;
		g[0] = 0;
		b[0] = 0;

		#(`clk_period);
		rst = 0;

		$display ("\n *** Color Space Converter testbench started ***\n");

		for (r_idx = 0; r_idx <= r_length; r_idx = r_idx + 1) begin
			for (g_idx = 0; g_idx <= g_length; g_idx = g_idx + 1) begin
				for (b_idx = 0; b_idx <= b_length; b_idx = b_idx + 1) begin
					@(posedge clk);
					r[0] <= r_idx;
					g[0] <= g_idx;
					b[0] <= b_idx;
				end
			end
		end
		
		$display ("\n *** Color Space Converter testbench ended ***\n");
		$finish;
	end

	integer n;
	always@(posedge clk)
	begin
		for (n = 0; n < 4; n = n + 1)
		begin
			r[n + 1] <= r[n];
			g[n + 1] <= g[n];
			b[n + 1] <= b[n];
		end
	end

	// the DUT needs 4 cycles to complete，so r[3], g[3], b[3]
	// are used to compute the golden values
	always@(r[3] or g[3] or b[3])
	begin
		my  = (299 * r[3]) + (587 * g[3]) + (114 * b[3]);
		if (my < 0)
			my = 0;

		my = my /1000;
		if (my > 1024)
			my = 1024;

		mcr = (500 * r[3]) - (419 * g[3]) - ( 81 * b[3]);
		if (mcr < 0)
			mcr = 0;

		mcr = mcr /1000;
		if (mcr > 1024)
			mcr = 1024;

		mcb = (500 * b[3]) - (169 * r[3]) - (332 * g[3]);
		if (mcb < 0)
			mcb = 0;

		mcb = mcb /1000;
		if (mcb > 1024)
			mcb = 1024;
	end

	// Check results
	always@(my or mcr or mcb)
	begin
		iy = y;
		if ( ( iy < my - emargin)  || (iy > my + emargin) )
			$display("Y-value error. Received %d, expected %d. R = %d, G = %d, B = %d", y, my, r[3], g[3], b[3]);

		icr = cr;
		if ( ( icr < mcr - emargin)  || (icr > mcr + emargin) )
			$display("Cr-value error. Received %d, expected %d. R = %d, G = %d, B = %d", cr, mcr, r[3], g[3], b[3]);

		icb = cb;
		if ( ( icb < mcb - emargin)  || (icb > mcb + emargin) )
			$display("Cb-value error. Received %d, expected %d. R = %d, G = %d, B = %d", cb, mcb, r[3], g[3], b[3]);
	end

endmodule