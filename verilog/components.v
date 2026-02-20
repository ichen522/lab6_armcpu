`timescale 1 ns / 100 ps
module pc(clk, rstb, wen, thread_id, next_pc, ex_branch, ex_thread_id, ex_branch_target, current_pc);
    input clk, rstb, wen, ex_branch;
    input [1:0] thread_id, ex_thread_id;
    input [8:0] next_pc, ex_branch_target;
    output reg [8:0] current_pc;

    reg [8:0] pc_regs [3:0]; 
    integer i;

    always @(*) current_pc = pc_regs[thread_id];

    always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
        for (i = 0; i < 4; i = i + 1)
            pc_regs[i] <= 9'b0;
    end 
    else begin
        if (wen) begin
            pc_regs[thread_id] <= next_pc;
        end

        if (ex_branch) begin
            pc_regs[ex_thread_id] <= ex_branch_target;
        end
    end
end
endmodule

`timescale 1 ns / 100 ps
module imem_bram (clk, addr, inst);
    input  wire        clk;
    input  wire [8:0]  addr;
    output reg  [31:0] inst;

    reg [31:0] rom_array [0:511];

    initial begin
        $readmemh("inst.mem", rom_array);
    end

    always @(posedge clk) begin
        inst <= rom_array[addr[8:2]];
    end
endmodule

`timescale 1 ns / 100 ps
module if_id_reg (clk, rstb, en, flush, if_pc, if_instr, if_thread_id, id_pc, id_instr, id_thread_id);
    input  wire        clk;
    input  wire        rstb;
    input  wire        en;  
    input  wire        flush;  

    input  wire [8:0]  if_pc;         
    input  wire [31:0] if_instr;      
    input  wire [1:0]  if_thread_id;  

    output reg  [8:0]  id_pc;
    output reg  [31:0] id_instr;
    output reg  [1:0]  id_thread_id;

    localparam ARM_NOP = 32'hE1A00000;

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            id_pc        <= 9'b0;
            id_instr     <= ARM_NOP; 
            id_thread_id <= 2'b0;
        end 
        else if (flush) begin
            id_pc        <= 9'b0;
            id_instr     <= ARM_NOP;
            id_thread_id <= 2'b0; 
        end 
        else if (en) begin
            id_pc        <= if_pc;
            id_instr     <= if_instr;
            id_thread_id <= if_thread_id;
        end
    end
endmodule

`timescale 1 ns / 100 ps
module id_ex_reg (clk, rstb, en, flush,id_alu_src, id_alu_ctrl,id_mem_read, id_mem_write,id_reg_write, id_mem_to_reg,
id_branch, id_cond,id_pc, id_instr,id_r1data, id_r2data,id_imm_out, id_wa,id_thread_id,
ex_alu_src, ex_alu_ctrl,ex_mem_read, ex_mem_write,ex_reg_write, ex_mem_to_reg, ex_branch, ex_cond,
ex_pc, ex_instr,ex_r1data, ex_r2data,ex_imm_out, ex_wa,ex_thread_id
);
    input  wire        clk;
    input  wire        rstb;
    input  wire        en;
    input  wire        flush;

    input  wire        id_alu_src;
    input  wire [3:0]  id_alu_ctrl;
    input  wire        id_mem_read;
    input  wire        id_mem_write;
    input  wire        id_reg_write;
    input  wire        id_mem_to_reg;
    input  wire        id_branch;
    input  wire [3:0]  id_cond;
    
    input  wire [8:0]  id_pc;
    input  wire [31:0] id_instr;
    input  wire [31:0] id_r1data;
    input  wire [31:0] id_r2data;
    input  wire [31:0] id_imm_out;
    input  wire [3:0]  id_wa;         
    input  wire [1:0]  id_thread_id;

    output reg         ex_alu_src;
    output reg  [3:0]  ex_alu_ctrl;
    output reg         ex_mem_read;
    output reg         ex_mem_write;
    output reg         ex_reg_write;
    output reg         ex_mem_to_reg;
    output reg         ex_branch;
    output reg  [3:0]  ex_cond;

    output reg  [8:0]  ex_pc;
    output reg  [31:0] ex_instr;
    output reg  [31:0] ex_r1data;
    output reg  [31:0] ex_r2data;
    output reg  [31:0] ex_imm_out;
    output reg  [3:0]  ex_wa;
    output reg  [1:0]  ex_thread_id;

    always @(posedge clk or negedge rstb) begin
        if (!rstb || flush) begin
            ex_mem_read   <= 0;
            ex_mem_write  <= 0;
            ex_reg_write  <= 0;
            ex_branch     <= 0;
            ex_thread_id  <= 2'b0;
            ex_alu_ctrl   <= 4'b0;
            ex_alu_src    <= 0;
            ex_mem_to_reg <= 0;
            ex_cond       <= 4'b1110; 
            ex_instr      <= 32'hE1A00000; 
        end 
        else if (en) begin
            ex_alu_src    <= id_alu_src;
            ex_alu_ctrl   <= id_alu_ctrl;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_reg_write  <= id_reg_write;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_branch     <= id_branch;
            ex_cond       <= id_cond;

            ex_pc         <= id_pc;
            ex_instr      <= id_instr;
            ex_r1data     <= id_r1data;
            ex_r2data     <= id_r2data;
            ex_imm_out    <= id_imm_out;
            ex_wa         <= id_wa;
            ex_thread_id  <= id_thread_id;
        end
    end
endmodule

`timescale 1 ns / 100 ps
module register_file (rg1, rg2, wd, wa, wen, w_thread,thread, r1data, r2data, clk, rst);
    input wire clk, rst, wen;
    input wire [1:0] thread, w_thread;
    input wire [3:0] rg1, rg2, wa;
    input wire [31:0] wd;
    output wire [31:0] r1data, r2data;

    reg [31:0] regfile [0:63];
    wire [5:0] r1, r2, w1;
    assign r1 = {thread, rg1};
    assign r2 = {thread, rg2};
    assign w1 = {w_thread, wa};

    assign r1data = (wen && (w1 == r1)) ? wd : regfile[r1];
    assign r2data = (wen && (w1 == r2)) ? wd : regfile[r2];

    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            regfile[i] = 32'b0;
    end

    always @(posedge clk) begin
       if(wen)begin
            regfile[w1] <= wd;
    end
    end
endmodule 

`timescale 1 ns / 100 ps 
module control_unit (instr, alu_src, alu_ctrl, imm_src, mem_read, mem_write, reg_write, mem_to_reg, branch, cond);
    input  wire [31:0] instr;

    output reg         alu_src;
    output reg [3:0]   alu_ctrl;
    output reg [1:0]   imm_src;

    output reg         mem_read;
    output reg         mem_write;

    output reg         reg_write;
    output reg         mem_to_reg;

    output reg         branch;
    output reg [3:0]   cond;

    wire [3:0] cond_field = instr[31:28];
    wire [2:0] op_high    = instr[27:25];  
    wire [1:0] op_mid     = instr[27:26];  

    wire       I_bit      = instr[25];     
    wire [3:0] opcode     = instr[24:21];  
    wire       S_bit      = instr[20];     

    wire       L_bit      = instr[20];     
    wire       U_bit      = instr[23];     

    wire       link_bit   = instr[24];     

    always @(*) begin
        alu_src    = 0;
        alu_ctrl   = 4'b0000;
        imm_src    = 2'b00;
        mem_read   = 0;
        mem_write  = 0;
        reg_write  = 0;
        mem_to_reg = 0;
        branch     = 0;
        cond       = cond_field;

        if (op_high == 3'b101) begin
            branch  = 1;
            imm_src = 2'b10;   

            if (link_bit)
                reg_write = 1; 
        end
        else if (op_mid == 2'b01) begin
            alu_src = ~I_bit;   
            imm_src = 2'b01;    

            if (U_bit)
                alu_ctrl = 4'b0000;  
            else
                alu_ctrl = 4'b0001;  

            if (L_bit) begin
                mem_read   = 1;
                mem_to_reg = 1;
                reg_write  = 1;
            end
            else begin
                mem_write = 1;
            end
        end
        else if (op_mid == 2'b00) begin
            if (instr[27:4] == 24'b000100101111111111110001) begin
                branch = 1;
            end
            else begin
                alu_src = I_bit;   
                imm_src = 2'b00;   

                case (opcode)
                    4'b0100: begin 
                        alu_ctrl  = 4'b0000;
                        reg_write = 1;
                    end
                    4'b0010: begin 
                        alu_ctrl  = 4'b0001;
                        reg_write = 1;
                    end
                    4'b1010: begin 
                        alu_ctrl  = 4'b0001;
                        reg_write = 0;   
                    end
                    4'b1101: begin 
                        alu_ctrl  = 4'b0010; 
                        reg_write = 1;
                    end
                    default: begin
                        reg_write = 0;
                    end
                endcase
            end
        end
    end
endmodule

`timescale 1 ns / 100 ps
module alu (A, B, alu_ctrl, result, flags);
    input  wire [31:0] A;
    input  wire [31:0] B;
    input  wire [3:0]  alu_ctrl;
    output reg  [31:0] result;
    output reg  [3:0]  flags;

    reg carry_out;
    reg overflow;

    always @(*) begin
        carry_out = 0;
        overflow  = 0;

        case (alu_ctrl)
            4'b0000: begin
                {carry_out, result} = A + B;
                overflow = (A[31] == B[31]) &&
                           (result[31] != A[31]);
            end
            4'b0001: begin
                {carry_out, result} = A - B;
                overflow = (A[31] != B[31]) &&
                           (result[31] != A[31]);
            end
            4'b0010: begin
                result = B;
            end
            4'b0011: begin
                result = A & B;
            end
            4'b0100: begin
                result = A | B;
            end
            4'b0101: begin
                result = A ^ B;
            end
            default: begin
                result = 32'b0;
            end
        endcase

        flags[3] = result[31];           
        flags[2] = (result == 32'b0);    
        flags[1] = carry_out;            
        flags[0] = overflow;             
    end
endmodule

`timescale 1 ns / 100 ps
module condition_check (cond, flags, pass);
    input  wire [3:0] cond;
    input  wire [3:0] flags;
    output reg        pass;

    wire N = flags[3];
    wire Z = flags[2];
    wire C = flags[1];
    wire V = flags[0];

    always @(*) begin
        case (cond)
            4'b0000: pass =  Z;                 
            4'b0001: pass = ~Z;                 
            4'b0010: pass =  C;                 
            4'b0011: pass = ~C;                 
            4'b0100: pass =  N;                 
            4'b0101: pass = ~N;                 
            4'b0110: pass =  V;                 
            4'b0111: pass = ~V;                 
            4'b1000: pass =  C & ~Z;            
            4'b1001: pass = ~C |  Z;            
            4'b1010: pass = (N == V);           
            4'b1011: pass = (N != V);           
            4'b1100: pass = ~Z & (N == V);      
            4'b1101: pass =  Z | (N != V);      
            4'b1110: pass = 1'b1;               
            default: pass = 1'b0;               
        endcase
    end
endmodule

`timescale 1 ns / 100 ps
module imm_gen (instr, imm_src, imm_out);
    input  wire [31:0] instr;
    input  wire [1:0]  imm_src;
    output reg  [31:0] imm_out;

    wire [11:0] imm12  = instr[11:0];
    wire [23:0] imm24  = instr[23:0];
    wire [7:0]  imm8   = instr[7:0];
    wire [3:0]  rotate = instr[11:8];

    always @(*) begin
        case (imm_src)
            2'b00: begin
                imm_out = {24'b0, imm8} >> (rotate * 2) |
                          {24'b0, imm8} << (32 - (rotate * 2));
            end
            2'b01: begin
                imm_out = {20'b0, imm12};
            end
            2'b10: begin
                imm_out = {{6{imm24[23]}}, imm24, 2'b00};
            end
            default: begin
                imm_out = 32'b0;
            end
        endcase
    end
endmodule

`timescale 1 ns / 100 ps
module cpsr_array (clk, rstb, thread_id, update_en, alu_flags, curr_flags);
    input  wire       clk;
    input  wire       rstb;
    input  wire [1:0] thread_id;  
    input  wire       update_en;  
    input  wire [3:0] alu_flags;  
    output wire [3:0] curr_flags;  

    reg [3:0] cpsr_regs [0:3];
    integer i;

    assign curr_flags = cpsr_regs[thread_id];

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            for (i = 0; i < 4; i = i + 1)
                cpsr_regs[i] <= 4'b0000;
        end 
        else if (update_en) begin
            cpsr_regs[thread_id] <= alu_flags;
        end
    end
endmodule

`timescale 1 ns / 100 ps
module data_memory (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,       
    input  wire [31:0] write_data, 
    output reg  [31:0] read_data   
);

    reg [31:0] dmem [0:255];
    wire [7:0] word_addr = addr[9:2];

    initial begin
        $readmemh("data_init.hex", dmem);
    end

    always @(posedge clk) begin
        if (mem_write) begin
            dmem[word_addr] <= write_data;
        end
        
        if (mem_read) begin
            read_data <= dmem[word_addr];
        end else begin
            read_data <= 32'b0; 
        end
    end
endmodule

`timescale 1 ns / 100 ps
module ex_mem_reg (
    input  wire        clk,
    input  wire        rstb,
    
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    input  wire        ex_reg_write,
    input  wire        ex_mem_to_reg,
    
    input  wire [31:0] ex_alu_result, 
    input  wire [31:0] ex_r2data,     
    input  wire [3:0]  ex_wa,         
    input  wire [1:0]  ex_thread_id,  
    
    output reg         mem_mem_read,
    output reg         mem_mem_write,
    output reg         mem_reg_write,
    output reg         mem_mem_to_reg,
    
    output reg  [31:0] mem_alu_result,
    output reg  [31:0] mem_write_data,
    output reg  [3:0]  mem_wa,
    output reg  [1:0]  mem_thread_id
);

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            mem_mem_read   <= 0;
            mem_mem_write  <= 0;
            mem_reg_write  <= 0;
            mem_mem_to_reg <= 0;
            mem_alu_result <= 32'b0;
            mem_write_data <= 32'b0;
            mem_wa         <= 4'b0;
            mem_thread_id  <= 2'b0;
        end else begin
            mem_mem_read   <= ex_mem_read;
            mem_mem_write  <= ex_mem_write;
            mem_reg_write  <= ex_reg_write;
            mem_mem_to_reg <= ex_mem_to_reg;
            
            mem_alu_result <= ex_alu_result;
            mem_write_data <= ex_r2data; 
            mem_wa         <= ex_wa;
            mem_thread_id  <= ex_thread_id;
        end
    end
endmodule

`timescale 1 ns / 100 ps
module mem_wb_reg (
    input  wire        clk,
    input  wire        rstb,
    
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,
    
    input  wire [31:0] mem_alu_result, 
    input  wire [31:0] mem_read_data,  
    input  wire [3:0]  mem_wa,         
    input  wire [1:0]  mem_thread_id,  
    
    output reg         wb_reg_write,
    output reg         wb_mem_to_reg,
    
    output reg  [31:0] wb_alu_result,
    output reg  [31:0] wb_read_data,
    output reg  [3:0]  wb_wa,
    output reg  [1:0]  wb_thread_id
);

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            wb_reg_write  <= 0;
            wb_mem_to_reg <= 0;
            wb_alu_result <= 32'b0;
            wb_read_data  <= 32'b0;
            wb_wa         <= 4'b0;
            wb_thread_id  <= 2'b0;
        end else begin
            wb_reg_write  <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
            wb_alu_result <= mem_alu_result;
            wb_read_data  <= mem_read_data;
            wb_wa         <= mem_wa;
            wb_thread_id  <= mem_thread_id;
        end
    end
endmodule

`timescale 1 ns / 100 ps
module barrel_shifter (
    input  wire [31:0] data_in,   
    input  wire [4:0]  shamt5,   
    input  wire [1:0]  sh_type,   
    output reg  [31:0] data_out   
);

    always @(*) begin
        if (shamt5 == 5'b0) begin
            data_out = data_in;
        end else begin
            case (sh_type)
                2'b00: data_out = data_in << shamt5;                 
                2'b01: data_out = data_in >> shamt5;                 
                2'b10: data_out = $signed(data_in) >>> shamt5;       
                2'b11: data_out = (data_in >> shamt5) | (data_in << (32 - shamt5));
            endcase
        end
    end
endmodule
