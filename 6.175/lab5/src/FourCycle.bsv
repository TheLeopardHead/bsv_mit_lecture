// FourCycle.bsv
//
// This is a four cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import DelayedMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

typedef enum {
	Fetch,
	Decode,
	Execute,
	WriteBack
} Stage deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr)		pc <- mkRegU;
    RFile			rf <- mkRFile;
    DelayedMemory	mem <- mkDelayedMemory;
    CsrFile			csrf <- mkCsrFile;

    Reg#(Stage)		stage <- mkReg(Fetch);

    Bool memReady = mem.init.done();
    Reg#(DecodedInst) dInst <- mkRegU();
	Reg#(ExecInst) eInst <- mkRegU();

	rule test (!memReady);
		let e = tagged InitDone;
		mem.init.request.put(e);
	endrule

	rule do_fetch ((stage == Fetch) && csrf.started && memReady);
		mem.req(MemReq{op: Ld, addr: pc, data: ?});
		stage <= Decode;
	endrule

	rule do_decode ((stage == Decode) && csrf.started && memReady);
		Data inst <- mem.resp();
		dInst <= decode(inst);
		stage <= Execute;
	endrule

	rule do_execute ((stage == Execute) && csrf.started && memReady);
		Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
		Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

		Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

		ExecInst eInst_tmp = exec(dInst, rVal1, rVal2, pc, ?, csrVal);

		if(eInst_tmp.iType == Ld) begin
			mem.req(MemReq{op: Ld, addr: eInst_tmp.addr, data: ?});
		end else if(eInst_tmp.iType == St) begin
			mem.req(MemReq{op: St, addr: eInst_tmp.addr, data: eInst_tmp.data});
		end

		// commit
        
        // check unsupported instruction at commit time. Exiting
        if(eInst_tmp.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

		eInst <= eInst_tmp;
		stage <= WriteBack;
	endrule
		/* 
		// These codes are checking invalid CSR index
		// you could uncomment it for debugging
		// 
		// check invalid CSR read
		if(eInst.iType == Csrr) begin
			let csrIdx = fromMaybe(0, eInst.csr);
			case(csrIdx)
				csrCycle, csrInstret, csrMhartid: begin
					$display("CSRR reads 0x%0x", eInst.data);
				end
				default: begin
					$fwrite(stderr, "ERROR: read invalid CSR 0x%0x. Exiting\n", csrIdx);
					$finish;
				end
			endcase
		end
		// check invalid CSR write
		if(eInst.iType == Csrw) begin
			let csrIdx = fromMaybe(0, eInst.csr);
			if(csrIdx != csrMtohost) begin
				$fwrite(stderr, "ERROR: invalid CSR index = 0x%0x. Exiting\n", csrIdx);
				$finish;
			end
			else begin
				$display("CSRW writes 0x%0x", eInst.data);
			end
		end
		*/

	rule do_writeback ((stage == WriteBack) && csrf.started && memReady);
		
		ExecInst eInst_tmp = eInst;

		if(eInst_tmp.iType == Ld) begin
			eInst_tmp.data <- mem.resp();
		end

		if(isValid(eInst_tmp.dst)) begin
			rf.wr(fromMaybe(?, eInst_tmp.dst), eInst_tmp.data);
		end

		pc <= eInst_tmp.brTaken ? eInst_tmp.addr : pc + 4;

		csrf.wr(eInst_tmp.iType == Csrw ? eInst_tmp.csr : Invalid, eInst_tmp.data);

		stage <= Fetch;
	endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
	$display("Start at pc 200\n");
	$fflush(stdout);
        pc <= startpc;
        stage <= Fetch;
    endmethod

	interface iMemInit = mem.init;
    interface dMemInit = mem.init;
endmodule


