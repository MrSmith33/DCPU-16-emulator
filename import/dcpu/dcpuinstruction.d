/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.dcpuinstruction;

import std.string : format;
import dcpu.constants;

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
				decodeOperand!false(operandB, format("%04x", nextWords[aNext])),
				decodeOperand!true(operandA, format("%04x", nextWords[0])));
		}
		else
		{
			auto aNext = nextWordOperands[operandA];
			return format("%04x %s %s", pc, specialOpcodeNames[opcode],
				decodeOperand!true(operandA, format("%04x", nextWords[0])));
		}
	}
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

string decodeOperand(bool isA)(ushort operand, lazy string nextWord)
{
	switch(operand)
	{
		case 0x00: .. case 0x07: // register
			return registerNames[operand];
		case 0x08: .. case 0x0f: // [register]
			return "["~registerNames[operand - 0x08]~"]";
		case 0x10: .. case 0x17: // [register + next word]
			return "["~registerNames[operand - 0x10]~" + 0x"~nextWord~"]";
		case 0x18: // PUSH / POP
			static if (isA) return "POP"; else return "PUSH";
		case 0x19: // [SP] / PEEK
			return "[SP]";
		case 0x1a: // [SP + next word]
			return "[SP + 0x"~nextWord~"]";
		case 0x1b: // SP
			return "SP";
		case 0x1c: // PC
			return "PC";
		case 0x1d: // EX
			return "EX";
		case 0x1e: // [next word]
			return "[0x"~nextWord~"]";
		case 0x1f: // next word
			return "0x"~nextWord;
		default: // 0xffff-0x1e (-1..30) (literal) (only for a)
			return format("0x%04x", cast(ushort)(operand - 0x21));
	}
}