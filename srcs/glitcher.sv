`timescale 1ns / 1ps
`default_nettype none


module form_glitcher (
    input wire clk,
    input wire trig,
    input wire [63:0] form,
    input wire [63:0] delay,
    output wire out
    );
    
    logic en;
    logic trig_edge;
    edge_detector (.clk, .in(trig), .pol(1'b1), .out(trig_edge));
    delay (.clk, .en(trig_edge), .delay, .ready(en));
    serializer64 (.clk, .en, .in(form), .out);
endmodule