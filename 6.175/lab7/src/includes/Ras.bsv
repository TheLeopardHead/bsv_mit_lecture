import Vector::*;
import ProcTypes::*;
import Types::*;

interface Ras#(numeric type size);
    method Action push(Addr addr);
    method ActionValue#(Maybe#(Addr)) pop();
endinterface

module mkRas(Ras#(size));
    Vector#(size, Reg#(Maybe#(Addr))) stack <- replicateM(mkReg(tagged Invalid));
    Reg#(Bit#(TLog#(size))) ptr <- mkReg(0);

    method Action push(Addr addr);
        if (ptr < fromInteger(valueOf(size) - 1)) begin
            ptr <= ptr + 1;
            stack[ptr + 1] <= tagged Valid addr;
        end else begin 
            ptr <= 0;
            stack[0] <= tagged Valid addr;
        end
        
    endmethod

    method ActionValue#(Maybe#(Addr)) pop();
        let r = stack[ptr];
        stack[ptr] <= tagged Invalid;
        if (ptr > 0) begin
            ptr <= ptr - 1;
        end else begin 
            ptr <= fromInteger(valueOf(size) - 1);
        end
        return r;

    endmethod
endmodule
