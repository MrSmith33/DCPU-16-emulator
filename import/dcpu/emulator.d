/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.emulator;

import std.conv : to;
import std.stdio;

import dcpu.dcpu;
static import dcpu.dcpu;
public import dcpu.dcpuemulation;
import dcpu.devices.idevice;
import dcpu.deviceproxy;

//@safe nothrow:

/// Does actual interpreting of DCPU-16
public class Emulator(CpuType)
{
	CpuType dcpu; /// data storage: memory, registers.

	void attachDevice(IDevice!CpuType device)
	{
		dcpu.attachDevice(device);
		device.attachEmulator(this);
	}

	void loadProgram(ushort[] binary)
	{
		ushort size = binary.length & 0xFFFF;

		dcpu.mem[0..size] = binary[0..size];
	}

	/// Performs next instruction
	void step()
	{
		ulong initialCycles = dcpu.regs.cycles;

		Instruction instr = dcpu.fetchNext();

		//writeln(instr);

		dcpu.execute(instr);

		// Handle interrupts only when interrupt queuing is disabled.
		// It may be enabled by interrupt handler or manually in time critical code.
		if (!dcpu.regs.queueInterrupts)
		{
			handleInterrupt(dcpu);
		}

		ulong diff = dcpu.regs.cycles - initialCycles;

		dcpu.updateQueue.onTick(diff);
		dcpu.regs.instructions = dcpu.regs.instructions + 1;

		dcpu.regs.observer.commitFrame(dcpu.regs.instructions);
		dcpu.mem.observer.commitFrame(dcpu.regs.instructions);

		foreach(IUndoable device; dcpu.devices.values)
		{
			device.commitFrame(dcpu.regs.instructions);
		}
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

	// Steps instructionsToStep instructions.
	void stepInstructions(ulong instructionsToStep)
	{
		foreach(_; 0..instructionsToStep)
		{
			step();
		}
	}

	/*/// Resets dcpu state and interpreter state to their initial state.
	void reset()
	{
		reset(dcpu);
	}*/
}