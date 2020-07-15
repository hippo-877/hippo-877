module apb_adapter_reg #(
    parameter  int RegAw = 8,
    parameter  int RegDw = 32,
    localparam int RegBw = RegDw/8
) (
    // APB interface
    input  logic                PCLK,
    input  logic                PRESETn,
    input  logic [10:0]         PADDR,
    input  logic                PSELx,
    input  logic                PENABLE,
    input  logic                PWRITE,
    input  logic [31:0]         PWDATA,
    output logic                PREADY,
    output logic [31:0]         PRDATA,
    output logic                PSLVERR,

    // Reg interface 
    output logic                re_o,
    output logic                we_o,
    output logic [RegAw-1:0]    addr_o,
    output logic [RegDw-1:0]    wdata_o,
    output logic [RegBw-1:0]    be_o,
    input  logic [RegDw-1:0]    rdata_i,
    input  logic                error_i 

);

logic       write_wait;
logic       read_wait;
logic       pready_r;

assign  read_wait = 1'b0;
assign  write_wait = 1'b0;

// state machine 
typedef enum {
    StIdle, StWrite_0, StWrite_1, StRead_0, StRead_1
}   apb_state_e;

apb_state_e apb_state, next_apb_state;

// combination logic of state machine 
always_comb  begin 
    next_apb_state = apb_state;
    unique case (apb_state)
    StIdle: begin
        if (PSELx & PWRITE) begin
            next_apb_state = StWrite_0;
        end else if (PSELx & ~PWRITE) begin
            next_apb_state = StRead_0;
        end
    end
    StWrite_0: begin
        if (!write_wait & PENABLE) begin
            next_apb_state = StWrite_1;
        end
    end
    StWrite_1: begin
        if (PSELx & PWRITE) begin 
            next_apb_state = StWrite_0;
        end else if (PSELx & ~PWRITE) begin
            next_apb_state = StRead_0;
        end else begin 
            next_apb_state = StIdle;
        end
    end
    StRead_0: begin
        if (!read_wait & PENABLE) begin 
            next_apb_state = StRead_1;
        end
    end
    StRead_1: begin
        if (PSELx & PWRITE) begin 
            next_apb_state = StWrite_0;
        end else if (PSELx & ~PWRITE) begin 
            next_apb_state = StRead_0;
        end else begin 
            next_apb_state = StIdle;
        end
    end
    default: begin 
        next_apb_state = StIdle;
    end
    endcase
end 

    // DFFs 
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin 
            apb_state <= StIdle;
            pready_r  <= 1'b0;
        end else begin 
            apb_state <= next_apb_state;
            pready_r  <= 1'b1;
        end
    end

    // Reg assignment 
    assign we_o = (next_apb_state == StWrite_1) ? 1'b1 : 1'b0;
    assign wdata_o = PWDATA;
    assign addr_o = PADDR;
    assign be_o = 4'b1111;
    assign re_o = (next_apb_state == StRead_0) ? 1'b1 : 1'b0;
    assign PRDATA = rdata_i;
    assign PSLVERR = ((apb_state == StWrite_1) && (apb_state == StRead_1)) ? error_i : 1'b0;
    assign PREADY = pready_r;

endmodule
