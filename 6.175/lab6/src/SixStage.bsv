// Two stage

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import FPGAMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} Decode2RegFetch deriving (Bits, Eq);

// Data structure for Fetch to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool epoch;
} RegFetch2Execute deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool epoch;
} Execute2Memory deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool epoch;
} Memory2WriteBack deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
	Addr pc;
	Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
	Scoreboard#(6)   sb <- mkCFScoreboard;
	FPGAMemory        iMem <- mkFPGAMemory;
    FPGAMemory        dMem <- mkFPGAMemory;
    CsrFile        csrf <- mkCsrFile;
    Btb#(6)         btb <- mkBtb; // 64-entry BTB

	// global epoch for redirection from Execute stage
	Reg#(Bool) exeEpoch <- mkReg(False);

	// EHR for redirection
	Ehr#(2, Maybe#(ExeRedirect)) exeRedirect <- mkEhr(Invalid);

	// FIFO between six stages
	Fifo#(2, Fetch2Decode) f2dFifo <- mkCFFifo;
    Fifo#(2, Decode2RegFetch) d2rFifo <- mkCFFifo;
    Fifo#(2, RegFetch2Execute) r2eFifo <- mkCFFifo;
	Fifo#(2, Maybe#(Execute2Memory)) e2mFifo <- mkCFFifo;
    Fifo#(2, Maybe#(Memory2WriteBack)) m2wFifo <- mkCFFifo;


    Bool memReady = iMem.init.done && dMem.init.done;
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

	// fetch stage 
	rule doFetch(csrf.started);
		// fetch
		iMem.req(MemReq {op: Ld, addr: pcReg[0], data: ?});
		Addr predPc = btb.predPc(pcReg[0]);
		pcReg[0] <= predPc;
		Fetch2Decode f2d = Fetch2Decode {
			pc: pcReg[0],
			predPc: predPc,
			epoch: exeEpoch
		};
		f2dFifo.enq(f2d);

		$display("Fetch: PC = %x", pcReg[0]);
	endrule

	//Decode Stage
	rule doDecode(csrf.started);
		f2dFifo.deq();
		Fetch2Decode f2d = f2dFifo.first;
		Data inst <- iMem.resp;
		// decode
		DecodedInst dInst = decode(inst);
		//enq
		Decode2RegFetch d2r = Decode2RegFetch {
			pc: f2d.pc,
			predPc: f2d.predPc,
			dInst: dInst,
			epoch: f2d.epoch
		};
		d2rFifo.enq(d2r);

		$display("Decode: PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst));
	endrule

	//RegFetch Stage
	rule doRegFetch(csrf.started);
		Decode2RegFetch d2r = d2rFifo.first;
		// reg read
		Data rVal1 = rf.rd1(fromMaybe(?, d2r.dInst.src1));
		Data rVal2 = rf.rd2(fromMaybe(?, d2r.dInst.src2));
		Data csrVal = csrf.rd(fromMaybe(?, d2r.dInst.csr));
		// data to enq to FIFO
		RegFetch2Execute r2e = RegFetch2Execute {
			pc: d2r.pc,
			predPc: d2r.predPc,
			dInst: d2r.dInst,
			rVal1: rVal1,
			rVal2: rVal2,
			csrVal: csrVal,
			epoch: d2r.epoch
		};
		// search scoreboard to determine stall
		if(!sb.search1(d2r.dInst.src1) && !sb.search2(d2r.dInst.src2)) begin
			// enq & update PC, sb
			r2eFifo.enq(r2e);
			d2rFifo.deq();
			sb.insert(d2r.dInst.dst);
			$display("RegFetch: PC = %x", d2r.pc);
		end
		else begin
			$display("RegFetch Stalled to avoid data hazard: PC = %x", d2r.pc);
		end
	endrule

	//Execute Stage
	rule doExecute(csrf.started);
		r2eFifo.deq();
		RegFetch2Execute r2e = r2eFifo.first;

		if(r2e.epoch != exeEpoch) begin
			// kill wrong-path inst, just deq sb
			e2mFifo.enq(tagged Invalid);
			$display("Execute: Stall and kill instruction");
		end
		else begin
			// execute
			ExecInst eInst = exec(r2e.dInst, r2e.rVal1, r2e.rVal2, r2e.pc, r2e.predPc, r2e.csrVal);  
			// check unsupported instruction at commit time. Exiting
			if(eInst.iType == Unsupported) begin
				$fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", r2e.pc);
				$finish;
			end

			// check mispred: with proper BTB, it is only possible for branch/jump inst 
			//under ppc = pc, there will be mispredictions for non-branch/jump insts..
			//this btb must be letting them redirect tho .. 
			//when the instruction that caused the misdirection is a store, the memory address for the store is set as next pc
			//unsuported instruction ensues...
			if(eInst.mispredict) begin //no btb update?
				$display("Execute finds misprediction: PC = %x", r2e.pc);
				exeRedirect[0] <= Valid (ExeRedirect {
					pc: r2e.pc,
					nextPc: eInst.addr // Hint for discussion 1: check this line
				});
			end

			Execute2Memory e2m = Execute2Memory {
				pc: r2e.pc,
				predPc: r2e.predPc,
				dInst: r2e.dInst,
				rVal1: r2e.rVal1,
				rVal2: r2e.rVal2,
				csrVal: r2e.csrVal,
				eInst: eInst,
				epoch: r2e.epoch
			};
			e2mFifo.enq(tagged Valid e2m);

			$display("Execute: PC = %x", r2e.pc);
		end
	endrule

	//Memory Stage
	rule doMemory(csrf.started);
		e2mFifo.deq();
		let e2m_maybe = e2mFifo.first;

		if (e2m_maybe matches tagged Valid .e2m) begin
			if(e2m.eInst.iType == Ld) begin
				dMem.req(MemReq{op: Ld, addr: e2m.eInst.addr, data: ?});
			end else if(e2m.eInst.iType == St) begin
				dMem.req(MemReq{op: St, addr: e2m.eInst.addr, data: e2m.eInst.data});
			end
			Memory2WriteBack m2w = Memory2WriteBack {
				pc: e2m.pc,
				predPc: e2m.predPc,
				dInst: e2m.dInst,
				rVal1: e2m.rVal1,
				rVal2: e2m.rVal2,
				csrVal: e2m.csrVal,
				eInst: e2m.eInst,
				epoch: e2m.epoch
			};
			m2wFifo.enq(tagged Valid m2w);
			$display("Memory: PC = %x", e2m.pc);
		end
		else begin
			$display("Memory: Stall and kill instruction");
			m2wFifo.enq(tagged Invalid);
		end
	endrule

	//WriteBack Stage 
	rule doWriteBack(csrf.started);
		m2wFifo.deq();
		let m2w_maybe = m2wFifo.first;
		if (m2w_maybe matches tagged Valid .m2w) begin
			let eInst = m2w.eInst;
			if(eInst.iType == Ld) begin
            	eInst.data <- dMem.resp;
        	end
			if(isValid(eInst.dst)) begin
				rf.wr(fromMaybe(?, eInst.dst), eInst.data);
			end
			csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
			$display("WriteBack: PC = %x", m2w.pc);
		end
		else begin
			$display("Memory: Stall and kill instruction");
		end
		// remove from scoreboard
		sb.remove;
	endrule

	(* fire_when_enabled *)
	(* no_implicit_conditions *)
	rule cononicalizeRedirect(csrf.started);
		if(exeRedirect[1] matches tagged Valid .r) begin
			// fix mispred
			pcReg[1] <= r.nextPc;
			exeEpoch <= !exeEpoch; // flip epoch
			btb.update(r.pc, r.nextPc); // train BTB
			$display("Fetch: Mispredict, redirected by Execute");
		end
		// reset EHR
		exeRedirect[1] <= Invalid;
	endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
		csrf.start(0); // only 1 core, id = 0
		// $display("Start at pc 200\n");
		// $fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

	interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

