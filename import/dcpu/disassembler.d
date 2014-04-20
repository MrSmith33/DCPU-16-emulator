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

	string nextWord()
	{
		if (pointer >= memory.length)
			return "???";
		else
			return format("%04x", memory[pointer++]);
	}

	string[] lines;
	ushort prevInstr = 0;
	string indent = "";

	void processInstr()
	{
		string instrStr;

		uint address = pointer;
		ushort instr = memory[pointer++];

		uint intHandlers;
		if (auto transition = find!"a.to == b"(memMap.transitions, address))
		{
			if (transition.length)
			{
				lines ~= "";
				
				Transition* trans = transition[0];

				if (trans.index == 0)
					lines ~= "start:";
				else if (trans.type == TransitionType.interrupt)
					lines ~= format("int_handler_%s:", trans.typeIndex);
				else
					lines ~= format("label_%s:", trans.index);
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
			string a = decodeOperand!true(instr >> 10, nextWord());
			string b = decodeOperand!false((instr >> 5) & 0x1F, nextWord());
			
			instrStr = format("0x%04x: %s", address, indent) ~ basicOpcodeNames[instr & 0x1F] ~ "  " ~ b ~ ", " ~ a;

			prevInstr = instr & 0x1F;
		}
		else if (((instr >> 5) & 0x1F) != 0)
		{
			instrStr = format("0x%04x: %s", address, indent) ~ specialOpcodeNames[(instr >> 5) & 0x1F] ~ "  " ~ decodeOperand!true(instr >> 10, nextWord());
			prevInstr = 0;
			indent = "";
		}
		else
		{
			instrStr = format("0x%04x: %s0x%02x 0x%02x, 0x%02x", address, indent, instr & 0x1F, (instr >> 5) & 0x1F, instr >> 10);
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