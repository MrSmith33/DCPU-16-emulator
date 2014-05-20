/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.dcpu.emulationstats;

import emulator.dcpu.constants;
import emulator.dcpu.instruction;

struct EmulationStatistics
{
	ulong totalInstrDone;
	ulong cyclesDone;
	ulong[32] basicDoneTimes;
	ulong[32] specialDoneTimes;
	ulong[4] sizesOfDoneInstrs;
	ulong[3] numOperandsDone;

	void onInstructionDone(ref const Instruction instr, ulong cycles)
	{			
		cyclesDone += cycles;
		++totalInstrDone;
		if (instr.operands == 2) ++basicDoneTimes[instr.opcode];
		else if (instr.operands == 1) ++specialDoneTimes[instr.opcode];
		
		++numOperandsDone[instr.operands];
		++sizesOfDoneInstrs[instr.size];
	}

	void onInstructionUndone(ref const Instruction instr, ulong cycles)
	{			
		cyclesDone -= cycles;
		--totalInstrDone;
		if (instr.operands == 2) --basicDoneTimes[instr.opcode];
		else if (instr.operands == 1) --specialDoneTimes[instr.opcode];
		
		--numOperandsDone[instr.operands];
		--sizesOfDoneInstrs[instr.size];
	}

	void reset()
	{
		totalInstrDone = 0;
		cyclesDone = 0;
		basicDoneTimes[] = 0;
		specialDoneTimes[] = 0;
		numOperandsDone[] = 0;
		sizesOfDoneInstrs[] = 0;
	}

	void print()
	{
		import std.stdio;

		writefln("---------------------------------- Statistics ----------------------------------");
		writefln("Cycles: %10s |  Basic   : %10s |  1w instr : %9s",
			cyclesDone, numOperandsDone[2], sizesOfDoneInstrs[1]);
		writefln("Instrs: %10s |  Special : %10s |  2w instr : %9s  Avg: %5.3s",
			totalInstrDone, numOperandsDone[1], sizesOfDoneInstrs[2],
			cast(double)(sizesOfDoneInstrs[1] + sizesOfDoneInstrs[2]*2 +
				sizesOfDoneInstrs[3]*3)/ totalInstrDone);
		writefln("Avg   : %10.4s |                       |  3w instr : %9s",
			cast(double)cyclesDone / totalInstrDone, sizesOfDoneInstrs[3]);
		writefln("------------------------------- Instruction info -------------------------------");
		
		uint inRow = 0;
		foreach(opcode; 0..32)
		{
			if (!isValidBasicOpcode[opcode]) continue;

			if (inRow == 6)
			{
				writeln; inRow = 0;
			}

			writef("%s %7s  ", basicOpcodeNames[opcode], basicDoneTimes[opcode]);

			++inRow;
		}

		foreach(opcode; 0..32)
		{
			if (!isValidSpecialOpcode[opcode]) continue;

			if (inRow == 6)
			{
				writeln; inRow = 0;
			}

			writef("%s %7s  ", specialOpcodeNames[opcode], specialDoneTimes[opcode]);

			++inRow;
		}

		stdout.flush();
	}
}