module memory(
    input  logic       clk,
    input  logic [7:0] addr, //cache address
    input logic wb_en,
    input logic [7:0] wb_addr, //address where the write back data be stored
    input logic [31:0] wb_data,
    output logic [31:0] data_out
);

logic [31:0] mem[0:255]; //1KB memory

initial begin
    mem[0] = 100;
    mem[1] = 200;
    mem[2] = 300;
    mem[3] = 400;
    mem[4] = 500;
    mem[5] = 600;
end

always_comb begin
    data_out = mem[addr]; 
end

always_ff @(posedge clk)
begin
    if(wb_en)
    begin
        mem[wb_addr]<=wb_data;  
//if write-back, datat be written into mem[addr] and gets updated
        $display("MEMORY UPDATED: mem[%0d] = %0d",
                 wb_addr,
                 wb_data);
    end
end

endmodule