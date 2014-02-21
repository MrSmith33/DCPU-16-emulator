/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.disassembler;

import std.string : format;


string[] disassemble(ushort[] memoryChunk)
{
	string[] lines;

	ushort pointer = 0;

	string decodeOperand(bool isA)(ushort operand)
	{
		switch(operand)
		{
			case 0x00: .. case 0x07: // register
				return registers[operand];
			case 0x08: .. case 0x0f: // [register]
				return "["~registers[operand - 0x08]~"]";
			case 0x10: .. case 0x17: // [register + next word]
				return "["~registers[operand - 0x10]~" + 0x"~nextWord()~"]";
			case 0x18: // PUSH / POP
				static if (isA) return "POP"; else return "PUSH";
			case 0x19: // [SP] / PEEK
				return "[SP]";
			case 0x1a: // [SP + next word]
				return "[SP + 0x"~nextWord()~"]";
			case 0x1b: // SP
				return "SP";
			case 0x1c: // PC
				return "PC";
			case 0x1d: // EX
				return "EX";
			case 0x1e: // [next word]
				return "[0x"~nextWord()~"]";
			case 0x1f: // next word
				return "0x"~nextWord();
			default: // 0xffff-0x1e (-1..30) (literal) (only for a)
				return format("0x%04x", cast(ushort)(operand - 0x21));
		}
	}

	string nextWord()
	{
		if (pointer >= memoryChunk.length)
			return "???";
		else
			return format("%04x", memoryChunk[pointer++]);
	}

	while(pointer < memoryChunk.length)
	{
		string instrStr;
		ushort instr = memoryChunk[pointer++];
		if ((instr & 0x1F) != 0)
		{
			string a = decodeOperand!true(instr >> 10);
			string b = decodeOperand!false((instr >> 5) & 0x1F);
			instrStr = basicOpcodes[instr & 0x1F] ~ " " ~ b ~ ", " ~ a;
		}
		else if (((instr >> 5) & 0x1F) != 0)
		{
			instrStr = specialOpcodes[(instr >> 5) & 0x1F] ~ " " ~ decodeOperand!true(instr >> 10);
		}
		else
			instrStr = "??? ";

		lines ~= instrStr;
	}

	return lines;
}

private static string[] registers = ["A", "B", "C", "X", "Y", "Z", "I", "J"];

private static string[] basicOpcodes = ["???", "SET", "ADD", "SUB", "MUL", "MLI", "DIV", "DVI", "MOD", "MDI", "AND", "BOR", "XOR",
"SHR", "ASR", "SHL", "IFB", "IFC", "IFE", "IFN", "IFG", "IFA", "IFL", "IFU", "???", "???", "ADX", "SBX", "???", "???", "STI", "STD"];
private static string[] specialOpcodes = ["???", "JSR", "???", "???", "???", "???", "???", "???", "INT", "IAG", "IAS", "RFI", "IAQ", "???",
"???", "???", "HWN", "HWQ", "HWI", "???", "???", "???", "???", "???", "???", "???", "???", "???", "???", "???", "???", "???"];