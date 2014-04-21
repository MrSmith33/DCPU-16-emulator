/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.disassembler;

import std.string : format;
import std.conv;

import dcpu.constants;
import dcpu.dcpuinstruction;
import dcpu.memoryanalyzer;

enum indentStr = "    ";

string[] disassembleSome(ushort[] memory, MemoryMap memMap, ushort location = 0, ushort count = 0)
{
	uint pointer = location;
	ushort numInstructions = 0;

	ushort nextWord()
	{
		if (pointer >= memory.length)
			return 0;
		else 
			return memory[pointer++];
	}

	string[] lines;
	ushort prevInstr = 0;
	string indent = "";

	void processInstr()
	{
		string instrStr;

		uint address = pointer;
		ushort instr = memory[pointer++];

		

		string literalDecoder(ushort literal)
		{
			if (auto transition = find!"a.from == b"(memMap.transitions, address))
			{
				if (transition.length && transition[0].target.position == literal)
				{
					return to!string(*(transition[0].target));
				}
			}

			return format("%#04x", literal);
		}

		// Place label if there is at current position
		if (auto labels = find!"(*a).position == b"(memMap.labels, address))
		{
			if (labels.length)
			{
				lines ~= "";
				lines ~= format("%s:", *labels[0]);
			}
		}

		if (instr == 0)
		{
			prevInstr = 0;
			indent = "";
			return;
		}

		if (prevInstr >= 0x10 && prevInstr <= 0x17) indent ~= indentStr;

		if ((instr & 0x1F) != 0)
		{
			string a = decodeOperand!true(instr >> 10, nextWord(), &literalDecoder);
			string b = decodeOperand!false((instr >> 5) & 0x1F, nextWord(), &literalDecoder);
			
			instrStr = format("%s%s  %s, %s", indent, basicOpcodeNames[instr & 0x1F], b, a);

			prevInstr = instr & 0x1F;
		}
		else if (((instr >> 5) & 0x1F) != 0)
		{
			instrStr = format("%s%s  %s",
				indent,
				specialOpcodeNames[(instr >> 5) & 0x1F],
				decodeOperand!true(instr >> 10, nextWord(), &literalDecoder));
			prevInstr = 0;
			indent = "";
		}
		else
		{
			instrStr = format("%s%#02x %#02x, %#02x", indent, instr & 0x1F, (instr >> 5) & 0x1F, instr >> 10);
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