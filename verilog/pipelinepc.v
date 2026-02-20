
`timescale 1 ns / 100 ps
module pipelinepc(
    input clk,
    input rstb
);

wire [8:0] current_pc;
wire [8:0] next_pc;
wire [8:0] pc_plus4;
wire [8:0] benq_addr;
wire [31:0] inst;
wire [8:0] id_pc;
wire [31:0] id_instr;
wire [1:0] id_thread_id;
wire sel_pc;
reg [1:0] thread_id_reg;

always @(posedge clk or negedge rstb) begin
    if (!rstb) 
        thread_id_reg <= 2'b00;
    else 
        thread_id_reg <= thread_id_reg + 1;
end

wire [1:0] thread_id = thread_id_reg;
assign pc_plus4 = current_pc + 9'd4;
assign next_pc = pc_plus4; 
wire [1:0]  ex_thread_id;
wire        actual_branch;
wire        wb_reg_write;
wire [3:0]  wb_wa;
wire [1:0]  wb_thread_id;
wire [31:0] wb_wd;

pc PC (
    .clk(clk),.rstb(rstb),.wen(1'b1), .thread_id(thread_id), .next_pc(next_pc),
    .ex_branch(actual_branch),.ex_thread_id(ex_thread_id),.ex_branch_target(benq_addr),
    
    .current_pc(current_pc));

imem_bram  IMEM(
    .clk(clk), .addr(current_pc), 
    
    .inst(inst));


if_id_reg IF_ID(
    .clk(clk),.rstb(rstb),.en(1'b1), .flush(actual_branch), .if_pc(next_pc), .if_instr(inst), .if_thread_id(thread_id),
    
    .id_pc(id_pc), .id_instr(id_instr), .id_thread_id(id_thread_id));

//---------------------------------------------ID--------------------------------------------------------------------
wire id_alu_src;
wire [3:0] id_alu_ctrl;
wire [1:0] id_imm_src;
wire id_mem_read;
wire id_mem_write;
wire id_reg_write;
wire id_mem_to_reg;
wire id_branch;
wire [3:0] id_cond;
wire [31:0] id_r1data;
wire [31:0] id_r2data;
wire [31:0] id_imm_out;
wire [3:0] id_rg2 = (id_mem_write) ? id_instr[15:12] : id_instr[3:0];


control_unit CU (
    .instr(id_instr),
    
    .alu_src(id_alu_src),.alu_ctrl(id_alu_ctrl),.imm_src(id_imm_src),.mem_read(id_mem_read),
    .mem_write(id_mem_write),.reg_write(id_reg_write),.mem_to_reg(id_mem_to_reg),.branch(id_branch),.cond(id_cond)
);

register_file RF (
    .clk(clk),.rst(rstb),.thread(id_thread_id), .rg1(id_instr[19:16]),     
    .rg2(id_rg2),.wen(wb_reg_write),.w_thread(wb_thread_id),.wa(wb_wa),.wd(wb_wd),                 

    .r1data(id_r1data),
    .r2data(id_r2data)
);


imm_gen ImmGen (
    .instr(id_instr),.imm_src(id_imm_src),

    .imm_out(id_imm_out)
);


wire [3:0] id_wa = id_instr[15:12]; 
wire ex_alu_src;
wire [3:0] ex_alu_ctrl;
wire ex_mem_read;
wire ex_mem_write;
wire ex_reg_write;
wire ex_mem_to_reg;
wire ex_branch;
wire [3:0] ex_cond;
wire [8:0] ex_pc;
wire [31:0] ex_instr;
wire [31:0] ex_r1data;
wire [31:0] ex_r2data;
wire [31:0] ex_imm_out;
wire [3:0] ex_wa;



id_ex_reg ID_EX (
    .clk(clk), .rstb(rstb), .en(1'b1), .flush(actual_branch), 
    .id_alu_src(id_alu_src), .id_alu_ctrl(id_alu_ctrl), .id_mem_read(id_mem_read),
    .id_mem_write(id_mem_write), .id_reg_write(id_reg_write), .id_mem_to_reg(id_mem_to_reg),
    .id_branch(id_branch), .id_cond(id_cond), .id_pc(id_pc), .id_instr(id_instr),
    .id_r1data(id_r1data), .id_r2data(id_r2data), .id_imm_out(id_imm_out),
    .id_wa(id_wa), .id_thread_id(id_thread_id),

    .ex_alu_src(ex_alu_src), .ex_alu_ctrl(ex_alu_ctrl), .ex_mem_read(ex_mem_read),
    .ex_mem_write(ex_mem_write), .ex_reg_write(ex_reg_write), .ex_mem_to_reg(ex_mem_to_reg),
    .ex_branch(ex_branch), .ex_cond(ex_cond), .ex_pc(ex_pc), .ex_instr(ex_instr),
    .ex_r1data(ex_r1data), .ex_r2data(ex_r2data), .ex_imm_out(ex_imm_out),
    .ex_wa(ex_wa), .ex_thread_id(ex_thread_id)
);


//---------------------------------------------EX -----------------------------------------------------------

wire [31:0] shifted_r2data;
wire [31:0] alu_operand_b;
wire [31:0] ex_alu_result;
wire [3:0]  ex_alu_flags;

barrel_shifter Shifter (
    .data_in(ex_r2data),
    .shamt5(ex_instr[11:7]),
    .sh_type(ex_instr[6:5]),
    .data_out(shifted_r2data)
);

assign alu_operand_b = (ex_alu_src) ? ex_imm_out : shifted_r2data;

alu ALU (
    .A(ex_r1data),
    .B(alu_operand_b),
    .alu_ctrl(ex_alu_ctrl),
    .result(ex_alu_result),
    .flags(ex_alu_flags)
);

wire [3:0] curr_flags;
wire condition_pass;

wire is_data_processing = (ex_instr[27:26] == 2'b00);
wire s_bit = ex_instr[20];
wire update_flags = is_data_processing & s_bit & condition_pass;

cpsr_array CPSR (
    .clk(clk),
    .rstb(rstb),
    .thread_id(ex_thread_id),
    .update_en(update_flags),
    .alu_flags(ex_alu_flags),
    .curr_flags(curr_flags)
);

condition_check CondCheck (
    .cond(ex_cond),
    .flags(curr_flags),
    .pass(condition_pass)
);

assign actual_branch     = ex_branch    & condition_pass;
wire actual_reg_write  = ex_reg_write & condition_pass;
wire actual_mem_write  = ex_mem_write & condition_pass;

wire is_bx = (ex_instr[27:4] == 24'b000100101111111111110001);
wire [8:0] b_target_addr = ex_pc + 9'd4 + ex_imm_out[8:0];
wire [8:0] branch_target_addr = is_bx ? ex_r2data[8:0] : b_target_addr;

assign sel_pc = actual_branch; 
assign benq_addr = branch_target_addr;
//---------------------------------------------MEM--------------------------------------------------------------------

wire mem_mem_read;
wire mem_mem_write;
wire mem_reg_write;
wire mem_mem_to_reg;
wire [31:0] mem_alu_result;
wire [31:0] mem_write_data;
wire [3:0]  mem_wa;
wire [1:0]  mem_thread_id;

ex_mem_reg EX_MEM (
    .clk(clk), .rstb(rstb),  .ex_mem_read(ex_mem_read),.ex_mem_write(actual_mem_write),   
    .ex_reg_write(actual_reg_write),.ex_mem_to_reg(ex_mem_to_reg),.ex_alu_result(ex_alu_result),       
    .ex_r2data(ex_r2data), .ex_wa(ex_wa),.ex_thread_id(ex_thread_id),        
    
    .mem_mem_read(mem_mem_read),.mem_mem_write(mem_mem_write),.mem_reg_write(mem_reg_write),.mem_mem_to_reg(mem_mem_to_reg),
    .mem_alu_result(mem_alu_result),.mem_write_data(mem_write_data),.mem_wa(mem_wa),.mem_thread_id(mem_thread_id)
);

wire [31:0] mem_read_data;

data_memory DMem (
    .clk(clk),.mem_read(mem_mem_read),.mem_write(mem_mem_write),.addr(mem_alu_result),.write_data(mem_write_data),        
     
    .read_data(mem_read_data)    
);

//---------------------------------------------WB -----------------------------------------------------------


wire wb_mem_to_reg;
wire [31:0] wb_alu_result;
wire [31:0] wb_read_data;

mem_wb_reg MEM_WB (
    .clk(clk),.rstb(rstb),.mem_reg_write(mem_reg_write),.mem_mem_to_reg(mem_mem_to_reg),
    .mem_alu_result(mem_alu_result),.mem_read_data(mem_read_data),    .mem_wa(mem_wa),.mem_thread_id(mem_thread_id),

    .wb_reg_write(wb_reg_write),.wb_mem_to_reg(wb_mem_to_reg),.wb_alu_result(wb_alu_result),
    .wb_read_data(wb_read_data),.wb_wa(wb_wa),.wb_thread_id(wb_thread_id)
);


assign wb_wd = (wb_mem_to_reg) ? wb_read_data : wb_alu_result;


endmodule
