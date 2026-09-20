// External pull-up; debounce press and release; update only in frame blank.
module edge_mode_button #(parameter DEBOUNCE_CYCLES = 1488000)(
    input clk, input rst_n, input key_n, input frame_blank,
    output reg cyber_mode
);
    (* ASYNC_REG = "TRUE" *) reg key_meta, key_sync;
    reg stable_key, requested_mode;
    reg [20:0] count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
            stable_key <= 1'b1;
            requested_mode <= 1'b0;
            cyber_mode <= 1'b0;
            count <= 0;
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;
            if (key_sync == stable_key) count <= 0;
            else if (count == DEBOUNCE_CYCLES - 1) begin
                count <= 0;
                stable_key <= key_sync;
                if (!key_sync) requested_mode <= ~requested_mode;
            end else count <= count + 1'b1;
            if (frame_blank) cyber_mode <= requested_mode;
        end
    end
endmodule
