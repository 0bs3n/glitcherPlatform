`timescale 1ns / 1ps
`default_nettype none

module top (
    input  wire clk,
    input  wire glitch_out_en,
    input  wire glitch_mode,
    input  wire LPC_reset,
    input  wire ftdi_rx,
    input  wire board_rx,
    input  wire etrig,
    input  wire delay_up,
    input  wire delay_dn,
    input  wire step_mode,
    input  wire reset_mask,
    input  wire swclk,
    input  wire swdio,
    output wire ftdi_tx,
    output wire board_tx,
    output logic  _reset,
    output logic  glitch_out,
    output logic  glitch_mon
    );
    
    // Pass through FTDI to target, useful for avoiding needing
    // an additional FTDI adapter to reflash target etc.
    assign ftdi_tx = board_rx;
    assign board_tx = ftdi_rx;
    
    // These values can be hardcoded if Vivado studio is not used,
    // see note below regarding VIO module
    wire [63:0] glitch_form;
    logic [63:0] glitch_delay;
    
    // Enables the Arty A7 face buttons to be used for shifting the input value up
    // or down, either a single time or 200x a second holding the modifier button.
    // useful for manually testing glitch timing.
    button_reg_shifter brsi(
            .clk,
            .up_en(delay_up),
            .dn_en(delay_dn),
            .step_mode,
            .value_out(glitch_delay)
        );
    
    // This is the current mechanism for monitoring the current
    // glitch delay (set via the buttons) and controlling the glitch
    // form and SWD data to match. Obviously this doesn't work if you're
    // adapting this code for some other FPGA that doesn't use Vivado.
    // Current solution for non-vivado builds is to just hardcode values
    // and rebuild when changes are made, but that's terrible -- currently
    // working on a UART transceiver module which can handle commands for
    // setting these values.
    vio_0 duty_delay_mon (
            .clk(clk),
            .probe_in0(glitch_delay),
            .probe_out0(glitch_form),
            .probe_out1(data_match)
        );
    
    logic glitchform_out;
    logic glitchform_out_etrig;
    
    form_glitcher SWD_fg(
            .clk, 
            .trig(swd_data_ready), 
            .form(glitch_form), 
            .out(glitchform_out), 
            .delay(glitch_delay)
        );
        
    form_glitcher eTrig_fg(
            .clk, 
            .trig(etrig), 
            .form(glitch_form), 
            .out(glitchform_out_etrig),
            .delay(glitch_delay)
        );
        
    logic swd_data_ready;
    logic [31:0] swd_data;
    logic [0:7] header;
    
    logic [31:0] data_match;
    // WARNING: at present the SWD module is HARDCODED to work with an SWD probe running at 1MHz.
    // See the note inside the module for more information and to adjust as needed for other probing
    // frequencies. This will be fixed soon, so that either A. there is no dependancy on SWCLK freq.
    // or B. that it is configurable over UART.
    swd_rx (.clk, .swclk_in(swclk), .swdio_in(swdio), .etrig, .rdy(swd_data_ready), .WData(swd_data), .Header(header));

    always_comb begin
        _reset = ~LPC_reset | reset_mask;
        if (glitch_mode) begin
            glitch_mon = glitchform_out & (swd_data == data_match);
            glitch_out = glitch_mon & glitch_out_en;
        end else begin
            glitch_mon = glitchform_out_etrig;
            glitch_out = glitch_mon & glitch_out_en;
        end
    end
endmodule