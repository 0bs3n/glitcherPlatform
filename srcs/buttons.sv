`timescale 1ns / 1ps
`default_nettype none


module button_reg_shifter (
    input wire clk,
    input reg up_en,
    input reg dn_en,
    input wire step_mode,
    output reg [31:0] value_out
    );
    
    wire btn_up_edge;
    wire btn_dn_edge;
    edge_detector edge1  (.clk, .in(up_en), .pol(1'b1), .out(btn_up_edge));
    edge_detector edge2 (.clk, .in(dn_en), .pol(1'b1), .out(btn_dn_edge));
    
    wire en_200Hz;  
    enable_interval delay_adjust_enable (.clk, .interval('d500_000), .en(en_200Hz));
    
    
    always_ff @ (posedge clk) begin
        if (step_mode == 1) begin
            if (en_200Hz) value_out <= up_en ? value_out + 1 : dn_en ? value_out == 0 ? value_out : value_out - 1 : value_out;
            else value_out <= value_out;
        end else begin
            value_out <= btn_up_edge ? value_out + 1 : btn_dn_edge ? value_out - 1 : value_out;
        end
    end    
endmodule