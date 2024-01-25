import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*;

interface Bht#(numeric type bhtIndex);
    method Addr predPC(Addr pc, Addr targetPC);
    method Action update(Addr pc, Bool taken);
endinterface

module mkBht(Bht#(bhtIndex)) provisos (Add#(a__, bhtIndex, 32));
    Vector#(TExp#(bhtIndex), Reg#(Bit#(2))) bhtArr <- replicateM(mkReg(2'b00));
	//use 2 bits prediction, 00: Strong Non-taken,  01:Weak Non-taken, 10: Weak Taken, 11: Strong Taken

    function Bit#(bhtIndex) getIndex(Addr pc);
        return truncate(pc >> 2);
    endfunction

    function Bit#(2) getEntry(Addr pc);
        return bhtArr[getIndex(pc)];
    endfunction

    function Bit#(2) update_state(Bit#(2) predBits, Bool taken);
        Bit#(2) new_predBits = ?;
		case(predBits)
		2'b00: new_predBits = (taken)? 2'b01 : 2'b00;
		2'b01: new_predBits = (taken)? 2'b11 : 2'b00;
		2'b10: new_predBits = (taken)? 2'b11 : 2'b00;
		2'b11: new_predBits = (taken)? 2'b11 : 2'b10;
		default: new_predBits = 2'b00;
		endcase
        return new_predBits;
    endfunction

    method Addr predPC(Addr pc, Addr targetPC);
        let predBits = getEntry(pc);
        let taken = (predBits == 2'b11 || predBits == 2'b10) ? True : False;
        let pred_pc = taken ? targetPC : pc + 4;
        return pred_pc;
    endmethod
    
    method Action update(Addr pc, Bool taken);
        let index  = getIndex(pc);
        let predBits = getEntry(pc);
        bhtArr[index] <= update_state(predBits, taken);
    endmethod
endmodule
