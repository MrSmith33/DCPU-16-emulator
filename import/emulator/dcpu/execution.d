/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.dcpu.execution;

import std.stdio;

import emulator.dcpu.dcpu;
import emulator.dcpu.devices.idevice;
import emulator.dcpu.constants;
import emulator.dcpu.disassembler;
import emulator.dcpu.instruction;
import emulator.utils.undoproxy;

void execute(Cpu)(ref Cpu dcpu, ref Instruction instr)
{
	if (instr.operands == 2)
		dcpu.basicInstruction(instr);
	else
		dcpu.specialInstruction(instr);
}

/// Performs basic instruction.
void basicInstruction(Cpu)(ref Cpu dcpu, ref Instruction instr)
{
	ushort pc = cast(ushort)(dcpu.regs.pc + 1); // pass opcode
	ushort sp = dcpu.regs.sp;

	ushort opcode = instr.opcode;

	OperandAccess aa = dcpu.getOperandA(instr.operandA, pc, sp); // will increase pc if reads next word

	OperandAccess ba = dcpu.getOperandB(instr.operandB, pc, sp); // will increase pc if reads next word

	dcpu.regs.pc = pc;
	dcpu.regs.sp = sp;

	dcpu.regs.cycles = dcpu.regs.cycles + basicCycles[opcode] + nextWordOperands[instr.operandA] + nextWordOperands[instr.operandB];
	
	ushort a = aa.get();
	ushort b = ba.get();

	uint result;

	with(dcpu) switch (opcode)
	{
		case 0x00 : assert(false); // Special opcode. Execution never goes here.
		case SET: result = a; break;
		case ADD: result = b + a; regs.ex = result >> 16; break;
		case SUB: result = b - a; regs.ex = (a > b) ? 0xFFFF : 0; break;
		case MUL: result = b * a; regs.ex = result >> 16; break;
		case MLI: result = cast(short)a * cast(short)b; regs.ex = result >> 16; break;
		case DIV: if (a==0){regs.ex = 0; result = 0;}
					else {result = b/a; regs.ex = ((b << 16)/a) & 0xFFFF;} break;
		case DVI: if (a==0){regs.ex = 0; result = 0;}
					else {
						result = cast(short)b/cast(short)a;
						regs.ex = ((cast(short)b << 16)/cast(short)a) & 0xFFFF;
					} break;
		case MOD: result = a == 0 ? 0 : b % a; break;
		case MDI: result = a == 0 ? 0 : cast(short)b % cast(short)a; break;
		case AND: result = a & b; break;
		case BOR: result = a | b; break;
		case XOR: result = a ^ b; break;
		case SHR: result = b >> a; regs.ex = ((b<<16)>>a) & 0xffff; break;
		case ASR: result = cast(short)b >>> a;
					regs.ex = ((b<<16)>>>a) & 0xffff; break;
		case SHL: result = b << a; regs.ex = ((b<<a)>>16) & 0xffff; break;
		case IFB: if ((b & a)==0) dcpu.skipIfs(); return;
		case IFC: if ((b & a)!=0) dcpu.skipIfs(); return;
		case IFE: if (b != a) dcpu.skipIfs(); return;
		case IFN: if (b == a) dcpu.skipIfs(); return;
		case IFG: if (b <= a) dcpu.skipIfs(); return;
		case IFA: if (cast(short)b <= cast(short)a) dcpu.skipIfs(); return;
		case IFL: if (b >= a) dcpu.skipIfs(); return;
		case IFU: if (cast(short)b >= cast(short)a) dcpu.skipIfs(); return;
		case ADX: result = b + a + regs.ex;
					regs.ex = (result >> 16) ? 1 : 0; break;
		case SBX: result = b - a + regs.ex; regs.ex = 0;
					if (ushort over = result >> 16)
						regs.ex = (over == 0xFFFF) ? 0xFFFF : 0x0001;
					break;
		case STI: ba.set(a); regs.i = cast(ushort)(regs.i + 1); regs.j = cast(ushort)(regs.j + 1); return;
		case STD: ba.set(a); regs.i = cast(ushort)(regs.i - 1); regs.j = cast(ushort)(regs.j - 1); return;
		default: {} //Invalid opcode
	}

	if (instr.operandB < 0x1F)
	{
		ba.set(result & 0xFFFF);
	}
}

/// Performs special instruction.
void specialInstruction(Cpu)(ref Cpu dcpu, ref Instruction instr)
{
	ushort opcode = instr.opcode;

	ushort pc = cast(ushort)(dcpu.regs.pc + 1);
	ushort sp = dcpu.regs.sp;

	OperandAccess aa = dcpu.getOperandA(instr.operandA, pc, sp);

	dcpu.regs.cycles = dcpu.regs.cycles + specialCycles[opcode] + nextWordOperands[instr.operandA];
	dcpu.regs.pc = pc;
	dcpu.regs.sp = sp;
	
	ushort a = aa.get();

	with(dcpu) switch (opcode)
	{
		case JSR: dcpu.push(regs.pc); regs.pc = a; break;
		case INT: dcpu.triggerInterrupt(a); break;
		case IAG: aa.set(regs.ia); break;
		case IAS: regs.ia = a; break;
		case RFI: regs.queueInterrupts = false;
					regs.a = dcpu.pop();
					regs.pc = dcpu.pop();
					break;
		case IAQ: regs.queueInterrupts = a > 0; break;
		case HWN: aa.set(numDevices); writefln("HWN %s %s pc:%04X", numDevices, aa.get(), regs.pc);break;
		case HWQ: dcpu.queryHardwareInfo(a); break;
		case HWI: dcpu.sendHardwareInterrupt(a); break;
		default : {}
	}
}

/// Pushes value onto stack decreasing reg_sp.
void push(Cpu)(ref Cpu dcpu, ushort value)
{
	dcpu.regs.sp = cast(ushort)(dcpu.regs.sp - 1);
	dcpu.mem[dcpu.regs.sp] = value;
}

/// Pops value from stack increasing reg_sp.
ushort pop(Cpu)(ref Cpu dcpu)
{
	dcpu.regs.sp = cast(ushort)(dcpu.regs.sp + 1);
	return dcpu.mem[(dcpu.regs.sp - 1) & 0xFFFF];
}

/// Sets A, B, C, X, Y registers to information about hardware deviceIndex
void queryHardwareInfo(Cpu)(ref Cpu dcpu, ushort deviceIndex)
{
	if (auto device = deviceIndex in dcpu.devices)
	{
		//writefln("%08x %04x %08x", device.hardwareId, device.hardwareVersion, device.manufacturer);
		dcpu.regs.a = device.hardwareId & 0xFFFF;
		dcpu.regs.b = device.hardwareId >> 16;
		dcpu.regs.c = device.hardwareVersion;
		dcpu.regs.x = device.manufacturer & 0xFFFF;
		dcpu.regs.y = device.manufacturer >> 16;
	}
	else
	{
		dcpu.regs[0..5] = [0, 0, 0, 0, 0];
	}
}

/// Sends an interrupt to hardware deviceIndex
void sendHardwareInterrupt(Cpu)(ref Cpu dcpu, ushort deviceIndex)
{
	//writefln("send interrupt %s", deviceIndex);
	if (auto device = deviceIndex in dcpu.devices)
	{
		dcpu.regs.cycles = dcpu.regs.cycles + device.handleInterrupt();
	}
}

/// Adds interrupt with message 'message' to dcpu.intQueue or starts burning DCPU if queue grows bigger than 256
void triggerInterrupt(Cpu)(ref Cpu dcpu, ushort message)
{
	if (dcpu.intQueue.isFull)
	{
		dcpu.isBurning = true;
	}
	else
	{
		dcpu.intQueue.pushBack(message);
	}
}

/// Handles interrupt from interrupt queue if reg_ia != 0 && intQueue.length > 0
/// Handles interrupts only when interrupt queuing is disabled.
/// It may be enabled by interrupt handler or manually in time critical code.
void handleInterrupt(Cpu)(ref Cpu dcpu)
{
	if (dcpu.intQueue.empty || dcpu.regs.queueInterrupts) return;

	ushort message = dcpu.intQueue.popFront();

	if (dcpu.regs.ia != 0)
	{
		dcpu.regs.queueInterrupts = true;

		push(dcpu, dcpu.regs.pc);
		push(dcpu, dcpu.regs.a);

		dcpu.regs.pc = dcpu.regs.ia;
		dcpu.regs.a = message;
	}
}

/++
+ Skips instructions if conditional opcode was failed.
+
+ The conditional opcodes take one cycle longer to perform if the test fails.
	+ When they skip a conditional instruction, they will skip an additional
	+ instruction at the cost of one extra cycle. This continues until a non-
	+ conditional instruction has been skipped. This lets you easily chain
	+ conditionals. Interrupts are not triggered while the DCPU-16 is skipping.
+/
void skipIfs(Cpu)(ref Cpu dcpu)
{
	ushort pc = dcpu.regs.pc;

	while ((dcpu.mem[pc] & 0x1F) >= IFB && (dcpu.mem[pc] & 0x1F) <= IFU)
	{
		dcpu.skip(pc);
	}

	dcpu.skip(pc);

	dcpu.regs.pc = pc;
}

void skip(Cpu)(ref Cpu dcpu, ref ushort pc)
{
	ushort instr = dcpu.mem[pc];
	ushort opcode = instr & 0x1F;

	if (opcode != 0) //basic
	{
		auto aNext = nextWordOperands[instr >> 10];
		auto bNext = nextWordOperands[(instr >> 5) & 0x1F];
		
		pc += 1 + aNext + bNext;
	}
	else //special
	{
		auto aNext = nextWordOperands[instr >> 10];
		pc += 1 + aNext;
	}

	dcpu.regs.inc!"cycles";
}