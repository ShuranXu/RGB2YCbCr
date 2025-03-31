#include "hls/ap_int.hpp"
#include "hls/ap_fixpt.hpp"
#include "hls/streaming.hpp"
#include <iostream>
#include <tuple>
#include <cmath>      // For std::abs

#define THRESHOLD           5

using namespace hls;

const int RGB_BITWIDTH = 8;
struct RGB {
    ap_uint<RGB_BITWIDTH> R;
    ap_uint<RGB_BITWIDTH> G;
    ap_uint<RGB_BITWIDTH> B;
};

const int YCBCR_BITWIDTH = 8;
struct YCbCr {
    ap_uint<YCBCR_BITWIDTH> Y;
    ap_uint<YCBCR_BITWIDTH> Cb;
    ap_uint<YCBCR_BITWIDTH> Cr;
};

// Fixed point type: Q12.6
// 12 integer bits and 6 fractional bits
typedef ap_fixpt<18, 12> fixpt_t;

// Top-level function to be synthesized as a FPGA IP block
void RGB2YCbCr_smarthls(hls::FIFO<RGB>   &input_fifo,
                        hls::FIFO<YCbCr> &output_fifo) {

#pragma HLS function top
#pragma HLS function pipeline

    RGB in = input_fifo.read();

    YCbCr ycbcr;

    // change divide by 256 to right shift by 8, add 0.5 for rounding
    ycbcr.Y = fixpt_t(4) + ((fixpt_t(65.738)*in.R + fixpt_t(129.057)*in.G + fixpt_t(25.064)*in.B ) >> 8) + fixpt_t(0.5);
    ycbcr.Cb = fixpt_t(128) - ((fixpt_t(37.945)*in.R + fixpt_t(74.494)*in.G - fixpt_t(112.439)*in.B) >> 8) + fixpt_t(0.5);
    ycbcr.Cr = fixpt_t(128) + ((fixpt_t(112.439)*in.R - fixpt_t(94.154)*in.G - fixpt_t(18.285)*in.B) >> 8) + fixpt_t(0.5);

    output_fifo.write(ycbcr);
}

// Clamp helper to keep values in range
uint8_t clamp(float value) {
    return static_cast<uint8_t>(std::max(0.0f, std::min(255.0f, value)));
}

// Convert a single RGB pixel to YCbCr in pure software
//
// Cb and Cr can be negative (they represent differences from the neutral gray). 
// Since 8-bit unsigned integers (uint8_t) can’t hold negative values, 
// the standard adds 128 as a "zero point" offset so:
// 
// Cb = 0 → stored as 128
// Cr = 0 → stored as 128
//
// This way, the neutral chroma is centered at 128, and the full range [-128, 127] 
// gets mapped into [0, 255].
//
std::tuple<uint8_t, uint8_t, uint8_t> RGB2YCbCr_sw(uint8_t R, uint8_t G, uint8_t B) {

    float Y  =  0.299f * R + 0.587f * G + 0.114f * B;
    float Cb = -0.169 * R - 0.332 * G + 0.5f * B + 128;
    float Cr =  0.5f * R - 0.419 * G - 0.0813 * B + 128;

    return std::make_tuple(clamp(Y), clamp(Cb), clamp(Cr));
}

int compareAndReport(uint8_t actual, uint8_t expected, const char* label, int threshold) {
    int diff = std::abs(static_cast<int>(actual) - static_cast<int>(expected));
    if (diff > threshold) {
        printf("Error: %s mismatch: actual =  %u, expected = %u, diff = %u\n", 
            label, actual, expected, diff);
        return 1;
    }
    return 0;
}

// Software testbench
int main() {

    hls::FIFO<RGB>   input_fifo(5);
    hls::FIFO<YCbCr> output_fifo(5);
    hls::FIFO<YCbCr> expected_fifo(5);

    RGB in;
    YCbCr out, expected;
    int err = 0;

    in.R = 0; in.G = 0; in.B = 0;
    for(int i = 0; i < 64; i++) {
        for(int j = 0; j < 64; j++) {
            for(int k = 0; k < 64; k++) {
                in.R = i;
                in.G = j;
                in.B = k;
                // HLS call
                input_fifo.write(in);
                RGB2YCbCr_smarthls(input_fifo, output_fifo);
                out = output_fifo.read();
                // SW call
                std::tuple<uint8_t, uint8_t, uint8_t> ycbcr = RGB2YCbCr_sw(in.R, in.G, in.B);
                uint8_t Y  = std::get<0>(ycbcr);
                uint8_t Cb = std::get<1>(ycbcr);
                uint8_t Cr = std::get<2>(ycbcr);
                // value check
                err += compareAndReport(out.Y, Y, "Y", THRESHOLD);
                err += compareAndReport(out.Cb, Cb, "Cb", THRESHOLD);
                err += compareAndReport(out.Cr, Cr, "Cr", THRESHOLD);
            }
        }
    }

    printf("Summary: %d mismatches\n", err);

    if(err == 0) {
        printf("PASS\n");
    } else {
        printf("FAIL\n");
    }

    return err;
}

