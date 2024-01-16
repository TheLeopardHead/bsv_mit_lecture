// TwoCycle.bsv
//
// This is a two cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

typedef enum {
	Fetch,
	Execute
} Stage deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    DMemory  mem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    Reg#(Stage) stage <- mkReg(Fetch);

    Bool memReady = mem.init.done();
    Reg#(DecodedInst) dInst <- mkRegU();

	rule test (!memReady);
		let e = tagged InitDone;
		mem.init.request.put(e);
	endrule

	rule do_fetch ((stage == Fetch) && csrf.started && memReady);
		Data inst <- mem.req(MemReq{op: Ld, addr: pc, data: ?});
		dInst <= decode(inst);
		stage <= Execute;
	endrule

	rule do_execute ((stage == Execute) && csrf.started && memReady);
		Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
		Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

		Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

		ExecInst eInst = exec(dInst, rVal1, rVal2, pc, ?, csrVal);

		if(eInst.iType == Ld) begin
			eInst.data <- mem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
		end else if(eInst.iType == St) begin
			let d <- mem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
		end

		// commit
        
        // check unsupported instruction at commit time. Exiting
        if(eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

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

		if(isValid(eInst.dst)) begin
			rf.wr(fromMaybe(?, eInst.dst), eInst.data);
		end

		pc <= eInst.brTaken ? eInst.addr : pc + 4;

		csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

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

    interface dMemInit = mem.init;
endmodule


