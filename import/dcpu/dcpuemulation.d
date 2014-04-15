/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.dcpuemulation;

import std.stdio;

import dcpu.dcpu;
import dcpu.devices.idevice;
import dcpu.deviceproxy;
import dcpu.disassembler;

struct Instruction
{
	ubyte opcode;
	ubyte operandA;
	ubyte operandB;
	ubyte size; // in words 1-3
	ubyte operands; // 2, 1, 0
	ushort pc;
	ushort[2] nextWords;

	string toString()
	{
		if (operands == 2)
		{
			auto aNext = nextWordOperands[operandA];
			auto bNext = nextWordOperands[operandB];
			return format("%04x %s %s %s", pc, basicOpcodes[opcode],
				decodeOperand!false(operandB, format("%04x", nextWords[aNext])),
				decodeOperand!true(operandA, format("%04x", nextWords[0])));
		}
		else
		{
			auto aNext = nextWordOperands[operandA];
			return format("%04x %s %s", pc, specialOpcodes[opcode],
				decodeOperand!true(operandA, format("%04x", nextWords[0])));
		}
	}
}

Instruction fetchNext(Cpu)(ref Cpu dcpu)
{
	return fetchAt(dcpu, dcpu.regs.pc);
}

Instruction fetchAt(Cpu)(ref Cpu dcpu, ushort address)
{
	Instruction result;

	ushort pc = address;
	ushort sp = dcpu.regs.sp;

	result.pc = pc;
	ushort instr = dcpu.mem[pc++];
	result.nextWords[0] = dcpu.mem[pc++];
	result.nextWords[1] = dcpu.mem[pc++];

	result.opcode = instr & 0b0000000000011111;
	++result.size;

	if (result.opcode != 0)
	{
		result.operandA = (instr & 0b1111110000000000) >> 10;
		if (nextWordOperands[result.operandA]) ++result.size;

		result.operandB = (instr & 0b0000001111100000) >> 5;
		if (nextWordOperands[result.operandB]) ++result.size;

		result.operands = 2;

		return result;
	}

	result.opcode = (instr  & 0b0000001111100000) >> 5;

	if (result.opcode != 0)
	{
		result.operandA = (instr & 0b1111110000000000) >> 10;
		if (nextWordOperands[result.operandA]) ++result.size;

		result.operands = 1;

		return result;
	}

	result.operands = 0;

	return result;
}

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
	ushort a = aa.get();

	OperandAccess ba = dcpu.getOperandB(instr.operandB, pc, sp); // will increase pc if reads next word
	ushort b = ba.get();

	dcpu.regs.pc = pc;
	dcpu.regs.sp = sp;

	dcpu.regs.cycles = dcpu.regs.cycles + basicCycles[opcode] + nextWordOperands[instr.operandA] + nextWordOperands[instr.operandB];
	
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
					else {result = b/a; regs.ex = ((b << 16)/a) & 0xFFFF;} break; // TODO:test
		case DVI: if (a==0){regs.ex = 0; result = 0;}
					else {
						result = cast(short)b/cast(short)a;
						regs.ex = ((cast(short)b << 16)/cast(short)a) & 0xFFFF;
					} break; // TODO:test
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
		case STI: result = a; regs.i = cast(ushort)(regs.i + 1); regs.j = cast(ushort)(regs.j + 1); break;
		case STD: result = a; regs.i = cast(ushort)(regs.i - 1); regs.j = cast(ushort)(regs.j - 1); break;
		default: ;//writeln("Unknown instruction " ~ to!string(instr.opcode)); //Invalid opcode
	}

	if (instr.operandB < 0x1F)
	{
		ba.set(result & 0xFFFF);
	}
	//else Attempting to write to a literal
}

/// Performs special instruction.
void specialInstruction(Cpu)(ref Cpu dcpu, ref Instruction instr)
{
	ushort opcode = instr.opcode;

	ushort pc = cast(ushort)(dcpu.regs.pc + 1);
	ushort sp = dcpu.regs.sp;

	OperandAccess aa = dcpu.getOperandA(instr.operandA, pc, sp);
	ushort a = aa.get();

	dcpu.regs.cycles = dcpu.regs.cycles + specialCycles[opcode] + nextWordOperands[instr.operandA];
	dcpu.regs.pc = pc;
	dcpu.regs.sp = sp;

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
		default : ;//writeln("Unknown instruction " ~ to!string(opcode));
	}
}


struct OperandAccess
{
	ushort delegate() get;
	ushort delegate(ushort) set;
}

OperandAccess memAccess(Cpu)(ref Cpu dcpu, ushort memLocation)
{
	return OperandAccess(
		{return dcpu.mem[memLocation];},
		(ushort value){return dcpu.mem[memLocation] = value;}
	);
}

OperandAccess regAccess(Cpu)(ref Cpu dcpu, ushort regLocation)
{
	return OperandAccess(
		{return dcpu.regs[regLocation];},
		(ushort value){return dcpu.regs[regLocation] = value;}
	);
}

OperandAccess litAccess(ushort literal)
{
	return OperandAccess(
		{return literal;},
		(ushort value){return literal;} // illegal. Fails silently
	);
}

OperandAccess getOperandA(Cpu)(ref Cpu dcpu, ushort operandBits, ref ushort pc, ref ushort sp)
{
	return getOperandValue!true(dcpu, operandBits, pc, sp);
}

OperandAccess getOperandB(Cpu)(ref Cpu dcpu, ushort operandBits, ref ushort pc, ref ushort sp)
{
	return getOperandValue!false(dcpu, operandBits, pc, sp);
}

/// Extracts operand value from a dcpu
OperandAccess getOperandValue(bool isA, Cpu)(ref Cpu dcpu, ushort operandBits, ref ushort pc, ref ushort sp)
in
{
	assert(operandBits <= 0x3F, "operand must be lower than 0x40");
	static if (!isA)
		assert(operandBits <= 0x1F);
}
body
{
	with(dcpu) switch(operandBits)
	{
		case 0x00: .. case 0x07: // register
			return dcpu.regAccess(operandBits);
		case 0x08: .. case 0x0F: // [register]
			return dcpu.memAccess(regs[operandBits & 7]);
		case 0x10: .. case 0x17: // [register + next word]
			return dcpu.memAccess((regs[operandBits & 7] + mem[pc++]) & 0xFFFF);
		case 0x18: // PUSH / POP
			static if (isA)
				return dcpu.memAccess(sp++);
			else
				return dcpu.memAccess(--sp);
		case 0x19: // [SP] / PEEK
			return dcpu.memAccess(sp);
		case 0x1a: // [SP + next word]
			return dcpu.memAccess(cast(ushort)(sp + mem[pc++]));
		case 0x1b: // SP
			return dcpu.regAccess(8);
		case 0x1c: // PC
			return dcpu.regAccess(9);
		case 0x1d: // EX
			return dcpu.regAccess(10);
		case 0x1e: // [next word]
			return dcpu.memAccess(mem[pc++]);
		case 0x1f: // next word
			return dcpu.memAccess(pc++);
		default: // 0xffff-0x1e (-1..30) (literal) (only for a)
			return litAccess(literals[operandBits & 0x1F]);
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
void handleInterrupt(Cpu)(ref Cpu dcpu)
{
	if (dcpu.intQueue.size == 0) return;

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

	dcpu.regs.cycles = dcpu.regs.cycles + 1;
}

/// Table of literal values which may be stored in 'a' operand.
private static ushort[32] literals =
	[0xFFFF, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
	 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
	 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
	 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E];

/// Operands which will read nex word increasing pc register are '1', other are '0'.
private static immutable ushort[64] nextWordOperands =
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
	 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ];

/// Table of basic instructions cost.
private static immutable ubyte[] basicCycles = 
	[10, 1, 2, 2, 2, 2, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1,
	 2, 2, 2, 2, 2, 2, 2, 2, 10, 10, 3, 3, 10, 10, 2, 2];

/// Table of special instructions cost.
private static immutable ubyte[] specialCycles = 
	[10, 3, 10, 10, 10, 10, 10, 10, 4, 1, 1, 3, 2, 10, 10, 10,
	 2, 4, 4, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10];

// Enums for opcodes. Just a bit of self documented code.
private enum {SET = 0x01, ADD, SUB, MUL, MLI, DIV, DVI, MOD, MDI, AND, BOR, XOR, SHR, ASR,
			SHL, IFB, IFC, IFE, IFN, IFG, IFA, IFL, IFU, ADX = 0x1A, SBX, STI = 0x1E, STD}
private enum {JSR = 0x01, INT = 0x08, IAG, IAS, RFI, IAQ, HWN = 0x10, HWQ, HWI}