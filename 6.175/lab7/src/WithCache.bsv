// Six Stage

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;
import Bht::*;
import Ras::*;
import Memory::*;
import SimMem::*;
import ClientServer::*;
import CacheTypes::*;
import WideMemInit::*;
import MemUtil::*;
import Cache::*;

typedef struct {
    Addr pc;
    Addr predPc;
	Bool d_epoch;
    Bool e_epoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool e_epoch;
} Decode2RegFetch deriving (Bits, Eq);

// Data structure for Fetch to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool e_epoch;
} RegFetch2Execute deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool e_epoch;
} Execute2Memory deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool e_epoch;
} Memory2WriteBack deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
	Addr pc;
	Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

// redirect msg from Decode stage
typedef struct {
	Addr pc;
	Addr nextPc;
} DcdRedirect deriving (Bits, Eq);


//(* synthesize *)
module mkProc#(Fifo#(2, DDR3_Req) ddr3ReqFifo, Fifo#(2, DDR3_Resp) ddr3RespFifo) (Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
	Scoreboard#(6)   sb <- mkCFScoreboard;
    CsrFile        csrf <- mkCsrFile;
    Btb#(6)         btb <- mkBtb; // 64-entry BTB
	Bht#(8)         bht <- mkBht; //256-entry BHT
	Ras#(8)			ras <- mkRas; //8-depth RAS

	// global epoch for redirection from Execute stage
	Reg#(Bool) exeEpoch <- mkReg(False);
	Reg#(Bool) dcdEpoch <- mkReg(False);

	// EHR for redirection
	Ehr#(2, Maybe#(ExeRedirect)) exeRedirect <- mkEhr(Invalid);
	Ehr#(2, Maybe#(DcdRedirect)) dcdRedirect <- mkEhr(Invalid);

	// FIFO between six stages
	Fifo#(2, Fetch2Decode) f2dFifo <- mkCFFifo;
    Fifo#(2, Decode2RegFetch) d2rFifo <- mkCFFifo;
    Fifo#(2, RegFetch2Execute) r2eFifo <- mkCFFifo;
	Fifo#(2, Maybe#(Execute2Memory)) e2mFifo <- mkCFFifo;
    Fifo#(2, Maybe#(Memory2WriteBack)) m2wFifo <- mkCFFifo;


    Bool memReady = True;
	WideMem					wideMemWrapper <- mkWideMemFromDDR3(ddr3ReqFifo, ddr3RespFifo);
	Vector#(2, WideMem)     wideMems <- mkSplitWideMem(memReady && csrf.started, wideMemWrapper);
	Cache iMem <- mkICache(wideMems[1]);
	Cache dMem <- mkDCache(wideMems[0]);

   	rule drainMemResponses( !csrf.started );
		ddr3RespFifo.deq;
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
			d_epoch: dcdEpoch,
			e_epoch: exeEpoch
		};
		f2dFifo.enq(f2d);

		$display("Fetch: PC = %x", pcReg[0]);
	endrule

	//Decode Stage
	rule doDecode(csrf.started);
		f2dFifo.deq();
		Fetch2Decode f2d = f2dFifo.first;
		Data inst <- iMem.resp;

		if(f2d.e_epoch == exeEpoch) begin
			if(f2d.d_epoch == dcdEpoch) begin
				// decode
				DecodedInst dInst = decode(inst);
				Addr ppc = f2d.predPc;
				Addr decoded_pc = f2d.pc + fromMaybe(?, dInst.imm);
				//RAS used for Jal push stack and Jal caculation & update
				if(dInst.iType == J) begin
					Addr target_j_pc = 	decoded_pc;
					if (target_j_pc != f2d.predPc) begin
						dcdRedirect[0] <= tagged Valid DcdRedirect {
                    		pc: f2d.pc,
                    		nextPc: target_j_pc
                		};
                		ppc = target_j_pc;
            		end
					if ( fromMaybe(?,dInst.dst) == 1) begin
						ras.push(f2d.pc + 4);
					end
				end
				//BHT Prediction 
				if (dInst.iType == Br) begin
					Addr target_br_pc = bht.predPC(f2d.pc, decoded_pc);
					if (target_br_pc != f2d.predPc) begin
						dcdRedirect[0] <= tagged Valid DcdRedirect {
                    		pc: f2d.pc,
                    		nextPc: target_br_pc
                		};
                		ppc = target_br_pc;
            		end
				end
				//RAS used for Jalr prediction
				if(dInst.iType == Jr) begin
					if ( fromMaybe(?,dInst.dst) == 1) begin
						ras.push(f2d.pc + 4);
					end
					else if((isValid(dInst.dst) == False) && (fromMaybe(?,dInst.src1) == 1)) begin
						let t <- ras.pop();
						Addr target_jr_pc = fromMaybe(f2d.predPc, t);
						if (target_jr_pc != f2d.predPc) begin
							dcdRedirect[0] <= tagged Valid DcdRedirect {
                    		pc: f2d.pc,
                    		nextPc: target_jr_pc
                		};
                		ppc = target_jr_pc;
						end
					end
				end
				//enq
				Decode2RegFetch d2r = Decode2RegFetch {
					pc: f2d.pc,
					predPc: ppc,
					dInst: dInst,
					e_epoch: f2d.e_epoch
				};
				d2rFifo.enq(d2r);

				$display("Decode: PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst));
			end
			else begin
				$display("Decode Stage Stall: Br or Jal or Jalr Redirect. PC = %x", f2d.pc);
			end
		end
		else begin
			$display("Decode Stage Stall: Execute Stage Redirect. PC = %x", f2d.pc);
		end
	endrule

	//RegFetch Stage
	rule doRegFetch(csrf.started);
		Decode2RegFetch d2r = d2rFifo.first;
		if(d2r.e_epoch == exeEpoch) begin
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
				e_epoch: d2r.e_epoch
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
		end
		else begin
			d2rFifo.deq();
			$display("RegFetch Stage Stall: Execute Stage Redirect. PC = %x", d2r.pc);
		end
	endrule

	//Execute Stage
	rule doExecute(csrf.started);
		r2eFifo.deq();
		RegFetch2Execute r2e = r2eFifo.first;

		if(r2e.e_epoch != exeEpoch) begin
			// kill wrong-path inst, just deq sb
			e2mFifo.enq(tagged Invalid);
			$display("Execute: Stall and kill instruction. PC = %x", r2e.pc);
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

			if (eInst.iType == Br) begin
                bht.update(r2e.pc, eInst.brTaken);
            end

			Execute2Memory e2m = Execute2Memory {
				pc: r2e.pc,
				predPc: r2e.predPc,
				dInst: r2e.dInst,
				rVal1: r2e.rVal1,
				rVal2: r2e.rVal2,
				csrVal: r2e.csrVal,
				eInst: eInst,
				e_epoch: r2e.e_epoch
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
				e_epoch: e2m.e_epoch
			};
			m2wFifo.enq(tagged Valid m2w);
			$display("Memory: PC = %x", e2m.pc);
		end
		else begin
			$display("Memory: Stall and kill instruction.");
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
			$display("Memory: Stall and kill instruction.");
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
		else if(dcdRedirect[1] matches tagged Valid .r) begin
			// fix mispred
            pcReg[1] <= r.nextPc;
            dcdEpoch <= !dcdEpoch; // flip epoch
            btb.update(r.pc, r.nextPc); // train BTB
            $display("Fetch: Mispredict, redirected by Decode");
        end

		// reset EHR
		exeRedirect[1] <= Invalid;
		dcdRedirect[1] <= Invalid;
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

endmodule

