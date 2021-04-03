`timescale 1ns / 1ps
`default_nettype none


module delay (
    input wire clk,
    input wire en,
    input wire [63:0] delay,
    output reg ready
    );
    
    typedef enum {
        STATE_IDLE,
        STATE_RUNNING
    } STATE;
    
    // we want to take an enable signal, one cycle wide,
    // and trigger another enable signal after n cycles
    
    //FIXME: There is a bug here somewhere that breaks the output
    //       when when it rolls over from 0 to -1. Current "fix"
    //       is to just never supply it a signed value < 0 lol
    
    logic [64:0] cnt;
    logic state = STATE_IDLE;
        
    always_ff @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                cnt <= 0;
                ready <= 0;
                state <= en ? STATE_RUNNING : STATE_IDLE;
            end
            STATE_RUNNING: begin
                state <= cnt == delay ? STATE_IDLE : STATE_RUNNING;
                ready <= cnt == delay ? 1 : 0;
                cnt <= cnt + 1;
            end
        endcase
    end
endmodule