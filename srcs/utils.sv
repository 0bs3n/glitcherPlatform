`timescale 1ns / 1ps
`default_nettype none


// Thanks to Andrew Zonenberg/Antikernel Labs for this handy synchronization module
module ThreeStageSynchronizer #(
	parameter INIT		= 0,
	parameter IN_REG	= 0
)(
	input wire clk_in,
	input wire din,
	input wire clk_out,

	(* ASYNC_REG = "TRUE" *)
	output logic dout	= INIT
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The flipflops

	logic dout0;

	(* ASYNC_REG = "TRUE" *) logic dout1;
	generate

		//First stage: FF in the transmitting domain
		if(IN_REG) begin
			always_ff @(posedge clk_in)
				dout0	<= din;
		end

		//Assume first stage is registered already in the sending module
		else begin
			always_comb
				dout0	<= din;
		end

	endgenerate

	//Two stages in the receiving clock domain
	always_ff @(posedge clk_out) begin
		dout1	<= dout0;
		dout	<= dout1;
	end

endmodule


module edge_detector (
    input wire clk,
    input wire in,
    input wire pol,
    output wire out
    );
    
    logic [2:0] buffer;
    assign out = pol ? buffer[1] & ~buffer[0] : ~buffer[1] & buffer[0];
    always_ff @(posedge clk) buffer <= { in, buffer[2:1] };
    
endmodule


module enable_interval (
    input wire clk,
    input wire logic [31:0] interval,
    output wire en
    );
    
    logic [31:0] cnt = 0;
    assign en = (cnt == interval) ? 1 : 0;
    always_ff @ (posedge clk) cnt <= cnt == interval ? 0 : cnt + 1;
        
endmodule


module duty_cycle (
    input wire clk,
    input wire logic [31:0] duty,
    input wire logic [31:0] delay,
    input wire enable,
    output wire signal_out
    );
    
    reg [31:0] current_tick = 0;
    always_ff @ (posedge clk) current_tick <= enable ? 0 : current_tick + 1;
    assign signal_out = ((current_tick < (delay + duty)) && (current_tick > delay));
    
endmodule


module resetter (
    input  wire clk,
    input  wire rst,
    output wire rst_out
    );
    
    logic [63:0] shift;
    assign rst_out = shift[0];
    always_ff @(posedge clk) shift <= rst ? 64'd0 : {1'b1, shift[63:1]};
    
endmodule


module inactivity_detect (
    input wire clk,
    input wire din,
    input wire [31:0] window,
    output reg out
    );
    
    logic [31:0] cnt = 0;
    logic rising_edge_detected, inactive;
    
    edge_detector (.clk, .in(din), .pol(1), .out(rising_edge_detected));
    edge_detector (.clk, .in(inactive), .pol(1), .out);
    
    always_ff @(posedge clk) begin
        if (rising_edge_detected) begin
            cnt <= 0;
            inactive <= 0;
        end else begin
            cnt <= cnt + 1;
            inactive <= cnt < window ? 0 : 1;
        end
    end
endmodule