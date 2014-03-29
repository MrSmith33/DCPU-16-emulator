/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.disassembler;

import std.string : format;

enum indentStr = "    ";

string[] disassembleSome(ushort[] memory, ushort location = 0, ushort count = 0)
{
	ushort pointer = location;
	ushort numInstructions = 0;

	string nextWord()
	{
		if (pointer >= memory.length)
			return "???";
		else
			return format("%04x", memory[pointer++]);
	}

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

	string[] lines;
	ushort prevInstr = 0;
	string indent = "";

	void processInstr()
	{
		string instrStr;

		ushort address = pointer;
		ushort instr = memory[pointer++];

		if (instr == 0)
		{
			prevInstr = 0;
			indent = "";
			return;
		}

		if (prevInstr >= 0x10 && prevInstr <= 0x17) indent ~= indentStr;


		if ((instr & 0x1F) != 0)
		{
			string a = decodeOperand!true(instr >> 10);
			string b = decodeOperand!false((instr >> 5) & 0x1F);
			
			instrStr = format("%04x: %s", address, indent) ~ basicOpcodes[instr & 0x1F] ~ " " ~ b ~ ", " ~ a;

			prevInstr = instr & 0x1F;
		}
		else if (((instr >> 5) & 0x1F) != 0)
		{
			instrStr = format("%04x: %s", address, indent) ~ specialOpcodes[(instr >> 5) & 0x1F] ~ " " ~ decodeOperand!true(instr >> 10);
			prevInstr = 0;
			indent = "";
		}
		else
		{
			instrStr = format("%04x: %s", address, indent) ~ format("0x%02x 0x%02x, 0x%02x", instr & 0x1F, (instr >> 5) & 0x1F, instr >> 10);
			prevInstr = 0;
			indent = "";
		}

		if (prevInstr < 0x10 || prevInstr > 0x17) indent = "";

		lines ~= instrStr;
		++numInstructions;
	}

	if (count > 0)
	{
		while(numInstructions < count && pointer < memory.length)
		{
			processInstr();
		}
	}
	else
	{
		while(pointer < memory.length)
		{
			processInstr();
		}
	}

	return lines;
}

private static string[] registers = ["A", "B", "C", "X", "Y", "Z", "I", "J"];

private static string[] basicOpcodes = ["0x00", "SET", "ADD", "SUB", "MUL", "MLI", "DIV", "DVI", "MOD", "MDI", "AND", "BOR", "XOR",
"SHR", "ASR", "SHL", "IFB", "IFC", "IFE", "IFN", "IFG", "IFA", "IFL", "IFU", "0x18", "0x19", "ADX", "SBX", "0x1c", "0x1d", "STI", "STD"];
private static string[] specialOpcodes = ["0x00", "JSR", "0x02", "0x03", "0x04", "0x05", "0x06", "0x07", "INT", "IAG", "IAS", "RFI", "IAQ", "0x0d",
"0x0e", "0x0f", "HWN", "HWQ", "HWI", "0x0d", "0x13", "0x14", "0x15", "0x16", "0x17", "0x18", "0x19", "0x1a", "0x1b", "0x1c", "0x1d", "0x1e", "0x1f"];