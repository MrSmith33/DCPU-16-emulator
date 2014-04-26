/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.disassembler;

import std.algorithm : joiner;
import std.conv : to;
import std.string : format;
import std.range : repeat;

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

	uint indentLevel;
	uint conditionIndentLevel;

	auto indent()
	{
		return indentStr.repeat(indentLevel + conditionIndentLevel).joiner;
	}

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

			return plainLitDecoder(literal);
		}

		// Place label if there is at current position
		if (auto labels = find!"(*a).position == b"(memMap.labels, address))
		{
			if (labels.length)
			{
				lines ~= "";
				lines ~= format("%04x  %s:", address, *labels[0]);

				indentLevel = 1;
			}
		}

		if (instr == 0)
		{
			prevInstr = 0;
			indentLevel = 0;
			conditionIndentLevel = 0;
			return;
		}

		if (prevInstr >= 0x10 && prevInstr <= 0x17)
		{
			++conditionIndentLevel;
		}

		if ((instr & 0x1F) != 0)
		{
			string a = decodeOperand!true(instr >> 10, nextWord(), &literalDecoder);
			string b = decodeOperand!false((instr >> 5) & 0x1F, nextWord(), &literalDecoder);
			
			instrStr = format("%04x  %s%s  %s, %s", address, indent, basicOpcodeNames[instr & 0x1F], b, a);

			prevInstr = instr & 0x1F;
		}
		else if (((instr >> 5) & 0x1F) != 0)
		{
			instrStr = format("%04x  %s%s  %s", address,
				indent,
				specialOpcodeNames[(instr >> 5) & 0x1F],
				decodeOperand!true(instr >> 10, nextWord(), &literalDecoder));
			
			prevInstr = 0;
		}
		else
		{
			instrStr = format("%04x  %s%#02x %#02x, %#02x", address, indent, instr & 0x1F, (instr >> 5) & 0x1F, instr >> 10);
			
			prevInstr = 0;
		}

		if (prevInstr < 0x10 || prevInstr > 0x17)
		{
			conditionIndentLevel = 0;
		}

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