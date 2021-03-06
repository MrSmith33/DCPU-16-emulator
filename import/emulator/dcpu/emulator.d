/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module emulator.dcpu.emulator;

import std.conv : to;
import std.stdio;

import emulator.dcpu.dcpu;
import emulator.dcpu.devices.idevice;
import emulator.utils.undoproxy;

public import emulator.dcpu.execution;
public import emulator.dcpu.instruction;
import emulator.dcpu.emulationstats;

//@safe nothrow:

/// Does actual interpreting of DCPU-16
public class Emulator(CpuType)
{
	CpuType dcpu; /// data storage: memory, registers.
	EmulationStatistics stats;

	void attachDevice(IDevice!CpuType device)
	{
		dcpu.attachDevice(device);
		device.attachEmulator(this);
	}

	void loadProgram(ushort[] binary)
	{
		ushort size = binary.length & 0xFFFF;

		dcpu.mem.observableArray[0..size*2] = cast(ubyte[])binary[0..size];
	}

	/// Performs next instruction
	void step(ulong numInstructions = 1)
	{
		foreach(_; 0..numInstructions)
		{
			ulong initialCycles = dcpu.regs.cycles;

			Instruction instr = dcpu.fetchNext();

			dcpu.execute(instr);

			handleInterrupt(dcpu);

			ulong diff = dcpu.regs.cycles - initialCycles;

			// Update statistics
			stats.onInstructionDone(instr, diff);

			// Update devices
			dcpu.updateQueue.onTick(diff);
			dcpu.regs.instructions = dcpu.regs.instructions + 1;

			// Commit changes to undo stack
			dcpu.regs.commitFrame(dcpu.regs.instructions);
			dcpu.mem.commitFrame(dcpu.regs.instructions);

			foreach(IUndoable device; dcpu.devices.values)
			{
				device.commitFrame(dcpu.regs.instructions);
			}
		}
	}

	void unstep(ulong numInstructions = 1)
	{
		ulong initialCycles = dcpu.regs.cycles;

		// Undo
		dcpu.regs.undoFrames(numInstructions);
		dcpu.mem.undoFrames(numInstructions);
		foreach(IUndoable device; dcpu.devices.values)
		{
			device.undoFrames(numInstructions);
		}

		// Update statistics
		Instruction instr = dcpu.fetchNext();
		stats.onInstructionUndone(instr, initialCycles - dcpu.regs.cycles);
	}

	// Tries to do cyclesToStep cycles of dcpu.
	// Returns actual cycles done.
	ulong stepCycles(ulong cyclesToStep)
	{
		ulong initialCycles = dcpu.regs.cycles;

		while(dcpu.regs.cycles - initialCycles < cyclesToStep)
		{
			step();
		}

		return dcpu.regs.cycles - initialCycles;
	}

	// Tries to undo cyclesToStep cycles of dcpu.
	// Returns actual cycles undone.
	ulong unstepCycles(ulong cyclesToStep)
	{
		ulong initialCycles = dcpu.regs.cycles;

		while(initialCycles - dcpu.regs.cycles < cyclesToStep && dcpu.regs.cycles > 0)
		{
			unstep(1);
		}

		if (dcpu.regs.cycles == 0)
		{
			dcpu.isRunning = false;
		}

		return initialCycles - dcpu.regs.cycles;
	}

	/// Resets dcpu state and interpreter state to their initial state.
	void reset()
	{
		foreach(IUndoable device; dcpu.devices.values)
		{
			device.discardUndoStack();
			device.discardFrame();
		}
		dcpu.reset();
		stats.reset();
	}

	size_t undoStackSize() @property
	{
		size_t result;

		result += dcpu.regs.undoStackSize;
		result += dcpu.mem.undoStackSize;
		foreach(IUndoable device; dcpu.devices.values)
		{
			result += device.undoStackSize;
		}

		return result;
	}
}