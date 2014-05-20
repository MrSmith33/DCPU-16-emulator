/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.dcpu.instruction;

import std.conv : to;
import std.string : format;

import emulator.dcpu.constants;

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
			return format("%04x %s %s %s", pc, basicOpcodeNames[opcode],
				decodeOperand!false(operandB, nextWords[aNext]),
				decodeOperand!true(operandA, nextWords[0]));
		}
		else
		{
			auto aNext = nextWordOperands[operandA];
			return format("%04x %s %s", pc, specialOpcodeNames[opcode],
				decodeOperand!true(operandA, nextWords[0]));
		}
	}
}

struct InstructionInfo
{
	bool isConditional;
	bool isValid;
	bool modifiesProgramCounter;
}

InstructionInfo instructionInfo(ref Instruction instr)
{
	InstructionInfo info;
	info.isConditional = isConditionalInstruction(instr);
	info.isValid = isValidInstruction(instr);
	//if (instr.operands == 2 && instr.operandB == )

	return info;
}

bool isValidInstruction(ref Instruction instr)
{
	if(instr.operands == 2)
		return isValidBasicOpcode[instr.opcode];
	else if(instr.operands == 1)
		return isValidSpecialOpcode[instr.opcode];
	else
		return false;
}

bool isConditionalInstruction(ref Instruction instr)
{
	return  instr.operands == 2 &&
			instr.opcode >= IFB &&
			instr.opcode <= IFU;
}

Instruction fetchNext(Cpu)(ref Cpu dcpu)
{
	return fetchAt(dcpu, dcpu.regs.pc);
}

alias MemoryAccessor = ushort delegate(ushort);

Instruction fetchAt(Cpu)(ref Cpu dcpu, ushort address)
{
	Instruction result;

	ushort pc = address;

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

alias LiteralDecoder = string delegate(ushort);

string delegate(ushort) plainLitDecoder;

static this()
{
	plainLitDecoder = delegate string(ushort literal)
	{
		return literal > 15 ? format("%#04x", literal) : to!string(literal);
	};
}

string decodeOperand(bool isA)(ushort operand, lazy ushort nextWord, LiteralDecoder literalDecoder = plainLitDecoder)
{
	switch(operand)
	{
		case 0x00: .. case 0x07: // register
			return registerNames[operand];
		case 0x08: .. case 0x0f: // [register]
			return "["~registerNames[operand - 0x08]~"]";
		case 0x10: .. case 0x17: // [register + next word]
			return "["~registerNames[operand - 0x10]~" + "~literalDecoder(nextWord)~"]";
		case 0x18: // PUSH / POP
			static if (isA) return "POP"; else return "PUSH";
		case 0x19: // [SP] / PEEK
			return "[SP]";
		case 0x1a: // [SP + next word]
			return "[SP + "~literalDecoder(nextWord)~"]";
		case 0x1b: // SP
			return "SP";
		case 0x1c: // PC
			return "PC";
		case 0x1d: // EX
			return "EX";
		case 0x1e: // [next word]
			return "["~literalDecoder(nextWord)~"]";
		case 0x1f: // next word
			return literalDecoder(nextWord);
		default: // 0xffff-0x1e (-1..30) (literal) (only for a)
			return literalDecoder(cast(ushort)(operand - 0x21));
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

// true if operand can be modified by opcode
static bool[64] isOperandRegister =
[1,1,1,1,1,1,1,1, // A-J
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,1,1,1,0,0,0, // SP, PC, EX
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,];

static bool[64] isOperandImmediate =
[0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,1,1,
 1,1,1,1,1,1,1,1,
 1,1,1,1,1,1,1,1,
 1,1,1,1,1,1,1,1,
 1,1,1,1,1,1,1,1,];

// true if operand can be modified by opcode or
// just by getting (like PUSH, POP modifies SP)
static bool[64] canOperandModifyRegister =
[1,1,1,1,1,1,1,1, // !-J
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 1,1,1,1,1,0,0,0, // --SP, SP++, SP, PC, EX
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,];