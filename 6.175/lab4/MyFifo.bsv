import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull;
        return !full;
    endmethod

    method Action enq(t x) if (full==False);

        Bit#(TLog#(n)) newP = 0;
        if (enqP == max_index) begin
            newP = 0;
        end else begin
            newP = enqP + 1;
        end
        enqP <= newP;
        full <= (newP == deqP);
        empty <= False;
        data[enqP] <= x;
    endmethod

    method Bool notEmpty;
        return !empty;
    endmethod

    method Action deq if (empty==False);
        Bit#(TLog#(n)) newP = 0;
        if (deqP == max_index) begin
            newP = 0;
        end else begin
            newP = deqP + 1;
        end
        deqP <= newP;

        empty <= (newP == enqP);
        full <= False;
    endmethod

    method t first if (empty==False);
        return data[deqP];
    endmethod

    method Action clear;
        enqP <= 0;
        deqP <= 0;
        empty <= True;
        full <= False;
    endmethod
endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear

module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Ehr#(3, (t)))     data     <- replicateM(mkEhrU());
    Ehr#(3, (Bit#(TLog#(n))))    enqP     <- mkEhr(0);
    Ehr#(3, (Bit#(TLog#(n))))    deqP     <- mkEhr(0);
    Ehr#(3, (Bool))              empty    <- mkEhr(True);
    Ehr#(3, (Bool))              full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull;
        return !full[1];
    endmethod

    method Action enq(t x) if (full[1]==False);

        Bit#(TLog#(n)) newP = 0;
        if (enqP[1] == max_index) begin
            newP = 0;
        end else begin
            newP = enqP[1] + 1;
        end
        enqP[1] <= newP;
        full[1] <= (newP == deqP[1]);
        empty[1] <= False;
        data[enqP[1]][1] <= x;
    endmethod

    method Bool notEmpty;
        return !empty[0];
    endmethod

    method Action deq if (empty[0]==False);
        Bit#(TLog#(n)) newP = 0;
        if (deqP[0] == max_index) begin
            newP = 0;
        end else begin
            newP = deqP[0] + 1;
        end
        deqP[0] <= newP;

        empty[0] <= (newP == enqP[0]);
        full[0] <= False;
    endmethod

    method t first if (empty[0]==False);
        return data[deqP[0]][0];
    endmethod

    method Action clear;
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod
endmodule


/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Ehr#(2, t))       data     <- replicateM(mkEhrU());  // Important
    Ehr#(3,Bit#(TLog#(n)))    enqP     <- mkEhr(0);
    Ehr#(3,Bit#(TLog#(n)))    deqP     <- mkEhr(0);
    Ehr#(3,Bool)              empty    <- mkEhr(True);
    Ehr#(3,Bool)              full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull;
        return !full[0];
    endmethod

    method Action enq(t x) if (full[0]==False);

        Bit#(TLog#(n)) newP = 0;
        if (enqP[0] == max_index) begin
            newP = 0;
        end else begin
            newP = enqP[0] + 1;
        end
        enqP[0] <= newP;
        full[0] <= (newP == deqP[0]);
        empty[0] <= False;
        data[enqP[0]][0] <= x;
    endmethod

    method Bool notEmpty;
        return !empty[1];
    endmethod

    method Action deq if (empty[1]==False);
        Bit#(TLog#(n)) newP = 0;
        if (deqP[1] == max_index) begin
            newP = 0;
        end else begin
            newP = deqP[1] + 1;
        end
        deqP[1] <= newP;

        empty[1] <= (newP == enqP[1]);
        full[1] <= False;
    endmethod

    method t first if (empty[1]==False);
        return data[deqP[1]][1];
    endmethod

    method Action clear;
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod
endmodule



//////////////////////
// Conflict free fifo

// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear

module mkMyCFNCFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))       data     <- replicateM(mkRegU());  // Important
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);
	Ehr#(3, Maybe#(t))		write 	 <- mkEhr(tagged Invalid);
	Ehr#(3, Maybe#(Bool))	read	 <- mkEhr(tagged Invalid);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

	function Bit#(TLog#(n)) roll_add(Bit#(TLog#(n)) in);
		Bit#(TLog#(n)) out = 0;
		if(in == max_index) begin out = 0; end
		else out = in + 1;
		return out;
	endfunction

	(* fire_when_enabled *)
	rule canonicalize;
		if(isValid(write[1]) && isValid(read[1])) begin
			enqP <= roll_add(enqP);
			deqP <= roll_add(deqP);
			full <= full;
			empty <= empty;
			data[enqP] <= fromMaybe(?, write[1]);
		end
		if(isValid(write[1]) && !isValid(read[1])) begin
			enqP <= roll_add(enqP);
			deqP <= deqP;
			full <= (roll_add(enqP) == deqP);
			empty <= False;
			data[enqP] <= fromMaybe(?, write[1]);
		end
		if(!isValid(write[1]) && isValid(read[1])) begin
			enqP <= enqP;
			deqP <= roll_add(deqP);
			full <= False;
			empty <= (enqP == roll_add(deqP));
		end
		if(!isValid(write[1]) && !isValid(read[1])) begin
			enqP <= enqP;
			deqP <= deqP;
			full <= full;
			empty <= empty;
		end
		write[1] <= tagged Invalid;
		read[1] <= tagged Invalid;
	endrule

    // TODO: Implement all the methods for this module

    method Bool notFull;
        return !full;
    endmethod

    method Action enq(t x) if (full == False);
		write[0] <= tagged Valid x;
    endmethod

    method Bool notEmpty;
        return !empty;
    endmethod

    method Action deq if (empty == False);
		read[0] <= tagged Valid False;
    endmethod

    method t first if (empty == False);
        return data[deqP];
    endmethod

//    method Action clear;
//        enqP[2] <= 0;
//        deqP[2] <= 0;
//        empty[2] <= True;
//        full[2] <= False;
//    endmethod

endmodule

module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Ehr#(3, t))       data     <- replicateM(mkEhrU());  // Important
    Ehr#(3, Bit#(TLog#(n)))    enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n)))    deqP     <- mkEhr(0);
    Ehr#(3, Bool)              empty    <- mkEhr(True);
    Ehr#(3, Bool)              full     <- mkEhr(False);
	Ehr#(3, Maybe#(t))		write 	 <- mkEhr(tagged Invalid);
	Ehr#(3, Maybe#(Bool))	read	 <- mkEhr(tagged Invalid);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

	function Bit#(TLog#(n)) roll_add(Bit#(TLog#(n)) in);
		Bit#(TLog#(n)) out = 0;
		if(in == max_index) begin out = 0; end
		else out = in + 1;
		return out;
	endfunction

	(* fire_when_enabled *)
	rule canonicalize;
		if(isValid(write[1]) && isValid(read[1])) begin
			enqP[1] <= roll_add(enqP[1]);
			deqP[1] <= roll_add(deqP[1]);
			full[1] <= full[1];
			empty[1] <= empty[1];
			data[enqP[1]][1] <= fromMaybe(?, write[1]);
		end
		if(isValid(write[1]) && !isValid(read[1])) begin
			enqP[1] <= roll_add(enqP[1]);
			deqP[1] <= deqP[1];
			full[1] <= (roll_add(enqP[1]) == deqP[1]);
			empty[1] <= False;
			data[enqP[1]][1] <= fromMaybe(?, write[1]);
		end
		if(!isValid(write[1]) && isValid(read[1])) begin
			enqP[1] <= enqP[1];
			deqP[1] <= roll_add(deqP[1]);
			full[1] <= False;
			empty[1] <= (enqP[1] == roll_add(deqP[1]));
		end
		if(!isValid(write[1]) && !isValid(read[1])) begin
			enqP[1] <= enqP[1];
			deqP[1] <= deqP[1];
			full[1] <= full[1];
			empty[1] <= empty[1];
		end
		write[1] <= tagged Invalid;
		read[1] <= tagged Invalid;
	endrule

    // TODO: Implement all the methods for this module

    method Bool notFull;
        return !full[1];
    endmethod

    method Action enq(t x) if (full[1] == False);
		write[0] <= tagged Valid x;
    endmethod

    method Bool notEmpty;
        return !empty[1];
    endmethod

    method Action deq if (empty[1] == False);
		read[0] <= tagged Valid False;
    endmethod

    method t first if (empty[1] == False);
        return data[deqP[1]][1];
    endmethod

    method Action clear;
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod

endmodule
