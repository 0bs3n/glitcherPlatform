`timescale 1ns / 1ps
`default_nettype none


module swd_rx (
    input  wire clk,
    input  wire swclk_in,
    input  wire swdio_in,
    input  wire etrig,
    input  wire [7:0] periodns,
    output logic [31:0] WData,
    output logic [0:7] Header,
    output logic rdy
    );
    
    logic swdio, swclk;
    
    ThreeStageSynchronizer (.din(swclk_in), .clk_out(clk), .dout(swclk));
    ThreeStageSynchronizer (.din(swdio_in), .clk_out(clk), .dout(swdio));
    
    logic host_clock, target_clock;
    edge_detector (.clk, .in(swclk), .pol(1), .out(host_clock));
    
    // the delay here is SWD frequency dependant! should be something around
    // 80% of period, so for the 1MHz signal I'm working with, that's
    // 800ns or 80 clock cycles as the internal 100MHz. Should implement
    // an input to do this dynamically. It's also possible that it isn't
    // needed at all, but the spec says there is a "minimum" of 10ns
    // between host reads and target writes when the target drives the bus.
    // That seems to be cutting it close for our clock
    delay (.clk, .en(host_clock), .delay('d80), .ready(target_clock));
    
    logic inactive;
    inactivity_detect (.clk, .din(swclk), .window('d200), .out(inactive));
    
    typedef enum {    
        IDLE,
        START,
        HEADER,
        ATRN,
        ACK,
        DTRN,
        DATA,
        PARITY,
        FTRN
    } State;
    
    typedef enum {
        HOST,
        TARGET
    } ClockSel;
    
    State state = IDLE;
    
    localparam header_length = 8;
    localparam data_length = 32;
    localparam ack_length = 3;

    logic [7:0] header_cursor = 0;
    logic [1:0] ack_cursor = 0;
    logic [7:0] data_cursor = 0;   
    
    logic [0:7] header;
    logic [0:2] ack;
    logic [31:0] data = 0;
    logic data_parity = 0;
    
    logic short_turn_flag = 0;
    
    wire current_clock;
    logic clock_selector = 0;
    assign current_clock = clock_selector ? target_clock : host_clock;
    
    // TODO: handling of turnaround periods is inconsistent.
    // HEADER -> ATRN, the actual TRN cycle elapses during the
    // HEADER stage, and ATRN doesn not wait for the next
    // SWCLK edge. However, 
    always_ff @(posedge clk) begin
        // hacky failsafe in case we get out of sync somehow.
        // TODO: figure out why we are going out of sync and fix
        // that instead of doing this ugly thing
        if (inactive) state <= IDLE;
        else begin
            case (state)           
                IDLE: begin
                    if (current_clock & swdio) state <= START;
                end
                
                // Reset counters/registers, clock in the start bit
                START: begin
                    ack <= 0;
                    data <= 0;
                    data_cursor <= 0;
                    ack_cursor <= 0;
                    
                    header <= { swdio, 7'b0 };
                    
                    header_cursor <= 1;
                    state <= HEADER;
                end
                
                // clock in the rest of the header { (start), APnDP, RnW, Addr[2:3], parity, stop, park }
                HEADER: begin
                    if (current_clock) begin
                        header_cursor <= header_cursor + 1;
                        if (header_cursor < header_length) header[header_cursor] <= swdio;
                        else state <= ATRN;
                    end
                end
                
                // Handle turn around period and start clocking slightly earlier
                // to compensate for the target writing on the rising edge
                ATRN: begin
                    clock_selector <= 1;
                    state <= ACK;
                end
                
                // Clock in the ACK and move to DATA or DTRN depending on if another
                // turnaround is needed (data write)
                ACK: begin
                    if (current_clock) begin
                        ack_cursor <= ack_cursor + 1;
                        if (ack_cursor < ack_length) ack[ack_cursor] <= swdio;
                        else state <= header[2] ? DATA : DTRN;
                    end
                    if (ack_cursor >= ack_length)
                        if (header[2]) state <= DATA;
                        else begin
                            state <= DTRN;
                            short_turn_flag <= 1;
                        end
                end
                
                // Handle turn around and reset to rising edge clock
                // also return to idle if ACK != OK, since no data will
                // follow in this packet
                DTRN: begin
                    if (current_clock) begin
                        if (short_turn_flag) begin
                            clock_selector <= 0;
                            short_turn_flag <= 0;
                        end
                        // Hacky error handling since we don't care about WAIT or FAULT responses
                        else state <= (ack == 'b100) ? DATA : IDLE;
                    end
                end
                
                // clock in 32 bits of data
                DATA: begin
                    if (current_clock) begin
                        data_cursor <= data_cursor + 1;
                        if (data_cursor < data_length) data[data_cursor] <= swdio;
                        else begin
                            state <= PARITY;
                            WData <= data;
                            Header <= header;
                            rdy <= 1;
                        end
                    end
                end     
                
                // clock in parity bit. Move to handle final turnaround
                // if it is needed (data read)
                PARITY: begin
                    rdy <= 0;
                    // if (current_clock) begin
                    data_parity <= swdio;
                    if (header[2]) begin
                        short_turn_flag <= 1;
                        state <= FTRN;
                    end
                    else state <= IDLE;
                    // end
                end
                
                // handle final turnaround, reset clock, return to idle
                FTRN: begin
                    if (current_clock) begin
                        if (short_turn_flag) begin
                            clock_selector <= 0;
                            short_turn_flag <= 0;
                        end
                        else state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Optional Vivado studio ILA module, not required -- remove as needed
    ila_0 ila (
        .clk,
        .probe0(etrig),
        .probe1(swdio),
        .probe2(target_clock),
        .probe3(rdy),
        .probe4(current_clock),
        .probe5(ack),
        .probe6(header),
        .probe7(state),
        .probe8(data),
        .probe9(swclk)
        );
       
endmodule