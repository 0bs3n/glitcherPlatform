`timescale 1ns / 1ps
`default_nettype none


module serializer64 (
    input  wire clk,
    input  wire en,
    input  wire [63:0] in,
    output reg out
    );
    
    typedef enum {
        STATE_IDLE,
        STATE_RUNNING
    } STATE;
    
    STATE state;
    
    logic [7:0] bit_count;
    logic [63:0] buffer;
    
    localparam input_width = 'd64;
    
    always_ff @(posedge clk) begin
        state <= en ? STATE_RUNNING : STATE_IDLE;
        case (state)
            STATE_IDLE: begin
                out <= 0;
                bit_count <= 0;
                state <= en ? STATE_RUNNING : STATE_IDLE;
                buffer <= en ? in : 0;
            end
            STATE_RUNNING: begin
                if (bit_count == input_width) begin
                    state <= STATE_IDLE;
                end else begin
                    bit_count <= bit_count + 1;
                    // reading as big-endian, since it makes more sense for a waveform
                    out <= buffer[63];
                    buffer <= { buffer[62:0], 1'b0 };
                    state <= STATE_RUNNING;
                end
            end
        endcase
    end    
endmodule