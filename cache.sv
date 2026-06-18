module cache(
input  logic        clk,
input logic cpu_req,
input logic shared_line,
input  logic [7:0]  addr,
input  logic [31:0] mem_data,
input  logic        write_en,
input  logic [31:0] write_data,
// Bus Snoop Signals
input  logic        BusRd,
input  logic        BusRdX,
input  logic        BusUpgr,
input  logic [7:0]  bus_addr,
output logic        hit,
output logic        miss,

output logic        wb_en,
output logic [7:0]  wb_addr,
output logic [31:0] wb_data,

output logic [31:0] cpu_data,

// Bus Request Signals
output logic        busrd_req,
output logic        busrdx_req,
output logic        busupgr_req,
output logic [7:0]  bus_req_addr
);

//////////////////////////////////////////////////
// MESI States
//////////////////////////////////////////////////

typedef enum logic [1:0] {
I = 2'b00,
S = 2'b01,
E = 2'b10,
M = 2'b11
} mesi_state_t;

//////////////////////////////////////////////////
// Cache Line
//////////////////////////////////////////////////

typedef struct packed {
mesi_state_t state;
logic [3:0]  tag;
logic [31:0] data;
} cache_line_t;

cache_line_t cache_mem[0:15];
logic pending_write_miss;
logic [3:0] tag;
logic [3:0] index;
logic pending_is_write;
logic [7:0]  pending_addr;
logic [31:0] pending_data;
logic [3:0] snoop_tag;
logic [3:0] snoop_index;
logic flush_valid;
logic [31:0] flush_data;
assign tag   = addr[7:4];
assign index = addr[3:0];

assign snoop_tag   = bus_addr[7:4];
assign snoop_index = bus_addr[3:0];

//////////////////////////////////////////////////
// Controller FSM States
//////////////////////////////////////////////////

typedef enum logic [2:0] {
IDLE,
COMPARE,
WRITE_BACK,
BUS_READ,
BUS_READX,
BUS_UPGR,
REFILL
}state_t;

state_t state, next_state;

//////////////////////////////////////////////////
// Initialization
//////////////////////////////////////////////////

integer i;

initial begin
for(i=0;i<16;i=i+1)
begin
    cache_mem[i].state = I;
    cache_mem[i].tag   = 0;
    cache_mem[i].data  = 0;
    pending_write_miss = 0;
    pending_is_write   = 0;
    pending_addr       = 0;
    pending_data       = 0;
end


state = IDLE;
pending_write_miss =0;
busrd_req    = 0;
busrdx_req   = 0;
busupgr_req  = 0;
bus_req_addr = 0;
end

//////////////////////////////////////////////////
// Hit / Miss Logic
//////////////////////////////////////////////////

always_comb begin

if(cache_mem[index].state != I &&
   cache_mem[index].tag   == tag)
begin
    hit  = 1;
    miss = 0;
end
else
begin
    hit  = 0;
    miss = 1;
end


end

//////////////////////////////////////////////////
// Data To CPU
//////////////////////////////////////////////////

always_comb begin


if(hit)
    cpu_data = cache_mem[index].data;
else
    cpu_data = mem_data;


end

//////////////////////////////////////////////////
// Next State Logic
//////////////////////////////////////////////////

always_comb begin

next_state = state;

case(state)

    IDLE:
    begin
    if(cpu_req)
        next_state = COMPARE;
    else
        next_state = IDLE;
    end

COMPARE:
begin

    if(hit)
    begin

        if(write_en)
        begin

            case(cache_mem[index].state)

                S: next_state = BUS_UPGR;

                E: next_state = IDLE;

                M: next_state = IDLE;

                default:
                    next_state = IDLE;

            endcase

        end
        else
        begin
            next_state = IDLE;
        end

    end

    else
    begin

        if(cache_mem[index].state == M)
            next_state = WRITE_BACK;

        else if(write_en)
            next_state = BUS_READX;

        else
            next_state = BUS_READ;

    end

end

WRITE_BACK:
begin

    if(pending_is_write)
        next_state = BUS_READX;
    else
        next_state = BUS_READ;

end
        
    BUS_READ:
        next_state = REFILL;
        
    BUS_READX:
    next_state = REFILL;

    REFILL:
        next_state = IDLE;
    BUS_UPGR:
        next_state = IDLE;

    default:
        next_state = IDLE;

endcase
end

//////////////////////////////////////////////////
// State Register
//////////////////////////////////////////////////

always_ff @(posedge clk)
begin
state <= next_state;
end

//////////////////////////////////////////////////
// Controller Actions
//////////////////////////////////////////////////

always_ff @(posedge clk)
begin

wb_en   <= 0;
wb_addr <= 0;
wb_data <= 0;

busrd_req    <= 0;
busrdx_req   <= 0;
busupgr_req  <= 0;
bus_req_addr <= 0;

case(state)

//////////////////////////////////////////////
// COMPARE
//////////////////////////////////////////////

COMPARE:
begin
$display(
"COMPARE hit=%0d write_en=%0d addr=%0d",
hit,
write_en,
addr
);
if(!hit)
begin

    pending_addr <= addr;
    pending_data <= write_data;

    if(write_en)
        pending_is_write <= 1;
    else
        pending_is_write <= 0;

end


    if(hit && write_en)
    begin

        case(cache_mem[index].state)

            M:
            begin
                cache_mem[index].data <= write_data;
            end

            E:
            begin
                cache_mem[index].data  <= write_data;
                cache_mem[index].state <= M;
            end

            S:
            begin
                // wait for BUS_UPGR state
            end

        endcase

    end

end

//////////////////////////////////////////////
// WRITE BACK
//////////////////////////////////////////////

WRITE_BACK:
begin

    wb_en   <= 1;
    wb_addr <= {cache_mem[index].tag,index};
    wb_data <= cache_mem[index].data;

    $display(
    "WRITE BACK : Addr=%0d Data=%0d",
    {cache_mem[index].tag,index},
    cache_mem[index].data
    );

end

//////////////////////////////////////////////
// BUS READ
//////////////////////////////////////////////

BUS_READ:
begin

    busrd_req    <= 1;
    bus_req_addr <= addr;

    $display(
    "BUSRD REQUEST : Addr=%0d",
    addr
    );

end

//////////////////////////////////////////////
// REFILL
//////////////////////////////////////////////

REFILL:
begin

   if(pending_write_miss)
begin

    cache_mem[pending_addr[3:0]].tag
        <= pending_addr[7:4];

    cache_mem[pending_addr[3:0]].data
        <= pending_data;

    cache_mem[pending_addr[3:0]].state
        <= M;

    pending_write_miss <= 0;
    pending_is_write   <= 0;

    $display(
    "REFILL -> M Addr=%0d Data=%0d",
    pending_addr,
    pending_data
    );

end

    else
    begin

        cache_mem[index].tag  <= tag;
        if(flush_valid)
          begin
            cache_mem[index].data <= flush_data;
            flush_valid <= 0;
          end
          else
            begin
              cache_mem[index].data <= mem_data;
            end

        if(shared_line)
        begin
            cache_mem[index].state <= S;
            $display("REFILL -> S");
        end
        else
        begin
            cache_mem[index].state <= E;
            $display("REFILL -> E");
        end

        $display(
        "REFILL : Addr=%0d Data=%0d",
        addr,
        mem_data
        );

    end

end
BUS_READX:
begin

    busrdx_req <= 1;
    bus_req_addr <= pending_addr;

    pending_write_miss <= 1;
    $display(
"DEBUG BUSRDX pending_addr=%0d pending_data=%0d",
pending_addr,
pending_data
);

end

BUS_UPGR:
begin

    busupgr_req <= 1;
    bus_req_addr <= addr;

    cache_mem[index].data <= write_data;
    cache_mem[index].state <= M;

end
endcase

end


//////////////////////////////////////////////////
// Snoop Logic
//////////////////////////////////////////////////

always_ff @(posedge clk)
begin
//////////////////////////////////////////////
// BusRd
//////////////////////////////////////////////

if(BusRd)
begin

   if(cache_mem[snoop_index].state != I &&
   cache_mem[snoop_index].tag == snoop_tag)
    begin

        case(cache_mem[snoop_index].state)

            E:
            begin
                cache_mem[snoop_index].state <= S;

                $display(
                "SNOOP : E -> S Addr=%0d",
                bus_addr
                );
            end

M:
begin
    
    wb_en <= 1;
    wb_addr <= {cache_mem[snoop_index].tag,snoop_index};
    wb_data <= cache_mem[snoop_index].data;
    flush_valid <= 1;
    flush_data  <= cache_mem[snoop_index].data;

    cache_mem[snoop_index].state <= S;

    $display("SNOOP : M -> S (Flush) Addr=%0d",bus_addr);
end
        endcase

    end

end
if(BusUpgr)
begin

    if(cache_mem[snoop_index].state != I &&
       cache_mem[snoop_index].tag == snoop_tag)
    begin

        if(cache_mem[snoop_index].state == S)
        begin

            cache_mem[snoop_index].state <= I;

            $display(
            "SNOOP : S -> I (BusUpgr) Addr=%0d",
            bus_addr
            );

        end

    end

end
if(BusRdX)
begin

    $display(
      "BUSRDX SEEN addr=%0d",
      bus_addr
    );

    if(cache_mem[snoop_index].state != I &&
       cache_mem[snoop_index].tag == snoop_tag)
    begin
        $display(
"SNOOP CHECK state=%0d tag=%0d snoop_tag=%0d addr=%0d",
cache_mem[snoop_index].state,
cache_mem[snoop_index].tag,
snoop_tag,
bus_addr
);

        case(cache_mem[snoop_index].state)

            S:
            begin
                cache_mem[snoop_index].state <= I;

                $display(
                "SNOOP : S -> I Addr=%0d",
                bus_addr
                );
            end

            E:
            begin
                cache_mem[snoop_index].state <= I;

                $display(
                "SNOOP : E -> I Addr=%0d",
                bus_addr
                );
            end

            M:
            begin

                wb_en   <= 1;
                wb_addr <= {cache_mem[snoop_index].tag,
                            snoop_index};

                wb_data <= cache_mem[snoop_index].data;

                cache_mem[snoop_index].state <= I;

                $display(
                "SNOOP : M -> I Addr=%0d",
                bus_addr
                );

            end



        endcase

    end

end

end

endmodule