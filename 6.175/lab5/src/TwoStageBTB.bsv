// TwoStageBtb.bsv
//
// This is a two stage btb implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import FIFOF::*;
import Ehr::*;
import GetPut::*;
import Btb::*;

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr)			pc <- mkRegU;
	Reg#(Addr)			exec_pc <- mkRegU;
	Reg#(Addr)			old_pc <- mkRegU;
    RFile				rf <- mkRFile;
    IMemory				iMem <- mkIMemory;
    DMemory				dMem <- mkDMemory;
    CsrFile				csrf <- mkCsrFile;
	Reg#(DecodedInst)	dInst <- mkRegU;
	Reg#(Bool)			flag_mispredict <- mkReg(False);
	Reg#(Bool)			flag_firstcycle <- mkReg(True);
	Btb#(6)				btb <- mkBtb();

    Bool memReady = iMem.init.done() && dMem.init.done();

    rule test (!memReady);
		let e = tagged InitDone;
		iMem.init.request.put(e);
		dMem.init.request.put(e);
    endrule

    rule process (csrf.started);

		if(flag_mispredict == True) begin
			old_pc <= exec_pc;
		end
		else begin
			old_pc <= pc;
		end

		if(flag_mispredict == True) begin
			pc <= exec_pc + 4;
		end
		else begin
			pc <= btb.predPc(pc);
		end


		Addr real_pc = (flag_mispredict == True) ? exec_pc : pc;	

		Data inst = iMem.req(real_pc);
        // decode
		dInst <= decode(inst);
		if(flag_firstcycle == True) begin
			flag_firstcycle <= False;
		end

		// trace - print the instruction
        $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));

		if(flag_firstcycle == False) begin

			$display("begin execute");
		if(flag_mispredict == False) begin
			DecodedInst dInst_tmp = dInst;		
			// read general purpose register values 
			Data rVal1 = rf.rd1(fromMaybe(?, dInst_tmp.src1));
			Data rVal2 = rf.rd2(fromMaybe(?, dInst_tmp.src2));

			// read CSR values (for CSRR inst)
			Data csrVal = csrf.rd(fromMaybe(?, dInst_tmp.csr));

			// execute
			ExecInst eInst = exec(dInst_tmp, rVal1, rVal2, old_pc, pc, csrVal);  
			// The fifth argument above is the predicted pc, to detect if it was mispredicted. 
			// Since there is no branch prediction, this field is sent with a random value

			// memory
			if(eInst.iType == Ld) begin
				eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
			end else if(eInst.iType == St) begin
				let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
			end

			// check unsupported instruction at commit time. Exiting
			if(eInst.iType == Unsupported) begin
				$fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
				$finish;
			end

			// write back to reg file
			if(isValid(eInst.dst)) begin
				rf.wr(fromMaybe(?, eInst.dst), eInst.data);
			end

			//update pc
			if(eInst.mispredict == True) begin
				btb.update(old_pc, pc);
				exec_pc <= eInst.addr;
				flag_mispredict <= True;
			end
			else begin
				exec_pc <= pc + 4;
			end

			// trace - print the instruction
        	$display("execute ");
			$display("eInst.addr=%x, old_pc=%x, eInst.mispredict=%d", eInst.addr, old_pc, eInst.mispredict);

			// CSR write for sending data to host & stats
			csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
		end
		else begin
			flag_mispredict <= False;
			$display("execute ");
			$display("pipeline stall, reset flag_mispredict");
		end
		end
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
		exec_pc <= startpc;
		flag_mispredict <= False;
		flag_firstcycle <= True;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

