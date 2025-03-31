/////////////////////////////////////////////////////////////////////
////                                                             ////
////  RGB to YCrCb Color Space converter                         ////
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

module rgb2ycrcb(clk, rst, r, g, b, y, cr, cb);
	//
	// inputs & outputs
	//
	input        clk;
	input        rst;
	input  [9:0] r, g, b;

	output reg [9:0] y, cr, cb;

	//
	// variables
	//
	reg [21:0] y1, cr1, cb1;


	// step 1: Calculate Y, Cr, Cb
	//
	// Use N.M format for multiplication:
	// Y  = 0.299 * R.000 + 0.587 * G.000 + 0.114 * B.000
	// Y  = 0x132 * R + 0x259 * G + 0x074 * B
    // 
    // Explanation:
    // 
    // Scaling the floating-point coefficients: Since the hardware or Verilog 
	// code likely deals with integer values, the floating-point coefficients
	// need to be scaled into integer format. 
    // The code uses a fixed-point representation where the coefficients are 
	// scaled by a factor of 2^10 = 1024 to retain precision while working with 
	// integers.
    //
    // 0.299 x 1024 = 306.176 ≈ 0x132 in hexadecimal.
    // 0.587 x 1024 = 601.088 ≈ 0x259 in hexadecimal.
    // 0.114 x 1024 = 116.736 ≈ 0x074 in hexadecimal.
    //
    // These hexadecimal values are then used as multipliers in the Verilog code.
    //
    // Scaling and converting to integers:
    //
    // 0.299 is represented as 0x132 (in base 16) after scaling by a factor of 1024.
    // 0.587 is represented as 0x259 (in base 16) after scaling by a factor of 1024.
    // 0.114 is represented as 0x074 (in base 16) after scaling by a factor of 1024.
	//
	// Cr = 0.713(R - Y)
	// Cr = 0.500 * R.000 + -0.419 * G.000 - 0.0813 * B.000
	// 
	// Similar to the scaling of Y, we scale Cr with 1024 as well:
	//
	// 0.500 x 1024 = 512 ≈ 0x200 in hexadecimal.
    // 0.419 x 1024 = 429.056 ≈ 0x1AD in hexadecimal.
    // 0.0813 x 1024 = 83.251 ≈ 0x053 in hexadecimal.
	//
	// This gives us:
	// Cr = 0x200 * R - 0x1AD * G - 0x053 * B
	// Cr = (1 << 9) * R - 0x1AD * G - 0x053 * B
	//
	// Cb = 0.565(B - Y)
	// Cb = -0.169 * R.000 + -0.332 * G.000 + 0.500 * B.000
	//
	// Similar to the scaling of Y and Cr, we scale Cb with 1024 as well:
	//
	// 0.500 x 1024 = 512 ≈ 0x200 in hexadecimal.
    // 0.169 x 1024 = 173.056 ≈ 0x0AD in hexadecimal.
    // 0.332 x 1024 = 339.968 ≈ 0x153 in hexadecimal.
	//
	//This gives us:
	//
	// Cb = B * 0x200 - 0x0AD * R - 0x153 * G
	// Cb = (B >> 1) - 0x0AD * R - 0x153 * G	


	// calculate Y
	reg [19:0] yr, yg, yb;

	always@(posedge clk)
		if (rst) begin
			yr <= 0;
			yb <= 0;
			yg <= 0;
			y1 <= 0;
		end else begin
			yr <= 10'h132 * r;
			yg <= 10'h259 * g;		
			yb <= 10'h074 * b;
			y1 <= yr + yg + yb;
		end

	// calculate Cr
	reg [19:0] crr, crg, crb;

	always@(posedge clk)
		if (rst) begin
			crr <= 0;
			crg <= 0;
			crb <= 0;
			cr1 <= 0;
		end else begin
			crr <= r << 9;
			crg <= 10'h1ad * g;		
			crb <= 10'h053 * b;
			cr1 <= crr - crg - crb;
		end

	// calculate Cb
	reg [19:0] cbr, cbg, cbb;

	always@(posedge clk)
		if (rst) begin
			cbr <= 0;
			cbg <= 0;
			cbb <= 0;
			cb1 <= 0;
		end else begin
			cbr <= 10'h0ad * r;
			cbg <= 10'h153 * g;		
			cbb <= b << 9;
			cb1 <= cbb - cbr - cbg;
		end

	//
	// step2: check boundaries
	//
	always@(posedge clk)
		if (rst) begin
			y <= 0;
			cr <= 0;
			cb <= 0;
		end else begin
			// check Y
			y <= (y1[19:10] & {10{!y1[21]}}) | {10{(!y1[21] && y1[20])}};
			// check Cr
			cr <= (cr1[19:10] & {10{!cr1[21]}}) | {10{(!cr1[21] && cr1[20])}};
			// check Cb
			cb <= (cb1[19:10] & {10{!cb1[21]}}) | {10{(!cb1[21] && cb1[20])}};
		end

	endmodule