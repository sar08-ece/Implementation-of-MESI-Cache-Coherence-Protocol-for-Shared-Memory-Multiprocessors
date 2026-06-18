module tb_cache;

logic clk;

/////////////////////////////////////////////////
// Shared Bus
/////////////////////////////////////////////////

logic BusRd;
logic BusRdX;
logic BusUpgr;
logic [7:0] bus_addr;
logic cpu_req0;
logic cpu_req1;
logic busrd_req0;
logic busrdx_req0;
logic busupgr_req0;
logic [7:0] bus_req_addr0;

logic busrd_req1;
logic busrdx_req1;
logic busupgr_req1;
logic [7:0] bus_req_addr1;

/////////////////////////////////////////////////
// CPU0 Signals
/////////////////////////////////////////////////

logic [7:0]  addr0;
logic [31:0] cpu_data0;
logic [31:0] data_out0;

logic hit0;
logic miss0;

logic write_en0;
logic [31:0] write_data0;

logic wb_en0;
logic [7:0]  wb_addr0;
logic [31:0] wb_data0;

/////////////////////////////////////////////////
// CPU1 Signals
/////////////////////////////////////////////////

logic [7:0]  addr1;
logic [31:0] cpu_data1;
logic [31:0] data_out1;

logic hit1;
logic miss1;

logic write_en1;
logic [31:0] write_data1;

logic wb_en1;
logic [7:0]  wb_addr1;
logic [31:0] wb_data1;

logic shared_line;
logic bus_owner;
/////////////////////////////////////////////////
// Cache 0
/////////////////////////////////////////////////

cache c0(
.clk(clk),
.addr(addr0),
.mem_data(data_out0),
.shared_line(shared_line),
.write_en(write_en0),
.write_data(write_data0),

.BusRd(BusRd),
.BusRdX(BusRdX),
.BusUpgr(BusUpgr),
.bus_addr(bus_addr),
.cpu_req(cpu_req0),
.hit(hit0),
.miss(miss0),

.wb_en(wb_en0),
.wb_addr(wb_addr0),
.wb_data(wb_data0),

.cpu_data(cpu_data0),

.busrd_req(busrd_req0),
.busrdx_req(busrdx_req0),
.busupgr_req(busupgr_req0),
.bus_req_addr(bus_req_addr0)
);

/////////////////////////////////////////////////
// Cache 1
/////////////////////////////////////////////////

cache c1(
.clk(clk),
.addr(addr1),
.mem_data(data_out1),
.shared_line(shared_line),
.write_en(write_en1),
.write_data(write_data1),
.cpu_req(cpu_req1),
.BusRd(BusRd),
.BusRdX(BusRdX),
.BusUpgr(BusUpgr),
.bus_addr(bus_addr),

.hit(hit1),
.miss(miss1),

.wb_en(wb_en1),
.wb_addr(wb_addr1),
.wb_data(wb_data1),

.cpu_data(cpu_data1),

.busrd_req(busrd_req1),
.busrdx_req(busrdx_req1),
.busupgr_req(busupgr_req1),
.bus_req_addr(bus_req_addr1)

);

/////////////////////////////////////////////////
// Memory 0
/////////////////////////////////////////////////

memory m0(
.clk(clk),
.addr(addr0),

.wb_en(wb_en0),
.wb_addr(wb_addr0),
.wb_data(wb_data0),

.data_out(data_out0)

);
/////////////////////////////////////////////////
// Memory 1
/////////////////////////////////////////////////

memory m1(
.clk(clk),
.addr(addr1),

.wb_en(wb_en1),
.wb_addr(wb_addr1),
.wb_data(wb_data1),

.data_out(data_out1)

);

/////////////////////////////////////////////////
// Bus Arbitration (Temporary)
/////////////////////////////////////////////////

always_comb
begin

    BusRd   = busrd_req0 | busrd_req1;
    BusRdX  = busrdx_req0 | busrdx_req1;
    BusUpgr = busupgr_req0 | busupgr_req1;

    if(busrd_req0 || busrdx_req0 || busupgr_req0)
    begin
        bus_addr  = bus_req_addr0;
        bus_owner = 0;
    end
    else
    begin
        bus_addr  = bus_req_addr1;
        bus_owner = 1;
    end

end
always_comb
begin

    shared_line = 0;

    if(BusRd)
    begin

        if(bus_owner == 0)
        begin

            if(
               c1.cache_mem[bus_addr[3:0]].state != c1.I &&
               c1.cache_mem[bus_addr[3:0]].tag   == bus_addr[7:4]
            )
                shared_line = 1;

        end

        else
        begin

            if(
               c0.cache_mem[bus_addr[3:0]].state != c0.I &&
               c0.cache_mem[bus_addr[3:0]].tag   == bus_addr[7:4]
            )
                shared_line = 1;

        end

    end

end

task print_states;
integer idx;
begin

    idx = bus_addr[3:0];

    $write(
    "T=%0t | IDX=%0d | C0=",
    $time,
    idx
    );

    case(c0.cache_mem[idx].state)
        c0.I: $write("I");
        c0.S: $write("S");
        c0.E: $write("E");
        c0.M: $write("M");
    endcase

    $write(" | C1=");

    case(c1.cache_mem[idx].state)
        c1.I: $write("I");
        c1.S: $write("S");
        c1.E: $write("E");
        c1.M: $write("M");
    endcase

    $display("");

end
endtask
always @(negedge clk)
begin
print_states();
end


/////////////////////////////////////////////////
// Clock
/////////////////////////////////////////////////

initial clk = 0;
always #5 clk = ~clk;

/////////////////////////////////////////////////
// Test
////////////////////////////////////////////////
initial begin

    write_en0   = 0;
    write_en1   = 0;

    write_data0 = 0;
    write_data1 = 0;

    cpu_req0 = 0;
    cpu_req1 = 0;

    addr0 = 0;
    addr1 = 0;

//////////////////////////////////////////////////
// STEP 1 : Cache0 Read
//////////////////////////////////////////////////

    $display("\nCACHE0 READ");

    addr0    = 8'd5;
    cpu_req0 = 1;

    #40;
    cpu_req0 = 0;

    #40;

//////////////////////////////////////////////////
// STEP 2 : Cache1 Read Same Address
//////////////////////////////////////////////////

    $display("\nCACHE1 READ SAME ADDRESS");

    addr1    = 8'd5;
    cpu_req1 = 1;

    #40;
    cpu_req1 = 0;

    #40;

//////////////////////////////////////////////////
// STEP 3 : Cache0 Write Same Address
//////////////////////////////////////////////////

    $display("\nCACHE0 WRITE SAME ADDRESS");

    addr0       = 8'd5;
    write_data0 = 32'd999;
    write_en0   = 1;
    cpu_req0    = 1;

    #40;

    cpu_req0  = 0;
    write_en0 = 0;

    #20;
    
$display("\nCACHE0 WRITE MISS");

addr0       = 8'd10;
write_en0   = 1;
write_data0 = 32'd777;
cpu_req0    = 1;

#40;

cpu_req0  = 0;
write_en0 = 0;

#60;

$display("\nCACHE1 READ MODIFIED LINE");

addr1    = 8'd10;
cpu_req1 = 1;

#40;

cpu_req1 = 0;

#80;

$display("\nCACHE1 WRITE TO MODIFIED LINE");

addr1       = 8'd10;
write_en1   = 1;
write_data1 = 32'd5555;
cpu_req1    = 1;

#40;

cpu_req1  = 0;
write_en1 = 0;

#40;

//////////////////////////////////////////////////
// CACHE1 WRITE MISS TO CACHE0 MODIFIED LINE
//////////////////////////////////////////////////

$display("\nCACHE1 WRITE MISS TO MODIFIED LINE");

addr1       = 8'd10;
write_en1   = 1;
write_data1 = 32'd9999;
cpu_req1    = 1;

#40;

cpu_req1  = 0;
write_en1 = 0;
#40;
//////////////////////////////////////////////////
// CACHE0 MAKE ADDRESS 5 MODIFIED
//////////////////////////////////////////////////

addr0       = 8'd5;
write_en0   = 1;
write_data0 = 32'd1111;
cpu_req0    = 1;

#20;

cpu_req0  = 0;
write_en0 = 0;

#60;

$display("\nCREATE M IN CACHE0");

addr0       = 8'd30;
write_en0   = 1;
write_data0 = 32'd3333;
cpu_req0    = 1;

#20;

cpu_req0  = 0;
write_en0 = 0;

#80;

$display("\nBUSRDX TEST M_TO_I");

addr1       = 8'd30;
write_en1   = 1;
write_data1 = 32'd4444;
cpu_req1    = 1;

#20;

cpu_req1  = 0;
write_en1 = 0;

#100;
//////////////////////////////////////////////////
// CACHE0 ACCESS DIFFERENT TAG SAME INDEX
//////////////////////////////////////////////////

addr0    = 8'd21;
cpu_req0 = 1;

#20;

cpu_req0 = 0;

#100;

#80;

    $finish;

end
endmodule