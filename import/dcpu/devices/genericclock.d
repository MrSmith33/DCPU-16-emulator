/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.devices.genericclock;

import std.stdio;

import anchovy.graphics.bitmap;

import dcpu.devices.idevice;
import dcpu.emulator;
import dcpu.dcpu;
import dcpu.undoproxy;

@trusted nothrow:

/++
 + Generic Clock (compatible) v1.0
 + See 'docs/generic clock.txt' for specification.
 +/

private struct ClockRegisters
{
	ulong initialCycles;
	ushort ticks;
	ushort divider;
	ulong tickPeriod;
	ushort interruptMessage;
}

class GenericClock(Cpu) : IDevice!Cpu
{
protected:
	Cpu* _dcpu;
	Emulator!Cpu _emulator;

	UndoableStruct!(ClockRegisters, ushort) regs;

public:
	/// Saves dcpu reference internally for future use.
	override void attachEmulator(Emulator!Cpu emulator)
	{
		_emulator = emulator;
		_dcpu = &emulator.dcpu;

		regs.ticks = 0;
		regs.divider = 0;
		regs.tickPeriod = 0;
		regs.interruptMessage = 0;
	}

	/// Handles hardware interrupt and returns a number of cycles.
	override uint handleInterrupt()
	{
		ushort aRegister = _emulator.dcpu.regs.a;
		ushort bRegister = _emulator.dcpu.regs.b;
		//writefln("Clock: int a:%s b:%s", aRegister, bRegister);

		switch(aRegister)
		{
			case 0:
				if (regs.divider != 0)
				{
					_dcpu.updateQueue.removeQueries(this);
				}

				regs.divider = bRegister;

				if (regs.divider != 0)
				{
					regs.tickPeriod = cast(ulong)(_dcpu.clockSpeed / (60.0 / regs.divider));
					_dcpu.updateQueue.addQuery(this, regs.tickPeriod, 0);
				}
				regs.ticks = 0;
				regs.initialCycles = _dcpu.regs.cycles;
				return 0;
			case 1:
				_dcpu.regs.b = regs.ticks;
				return 0;
			case 2:
				regs.interruptMessage = bRegister;
				return 0;
			default:
				break;
		}

		return 0;
	}

	/// Called every application frame.
	/// Can be used to update screens.
	override void updateFrame()
	{
	}

	/// Must handle previosly posted update query.
	/// If next updates is not needed must set delay to zero.
	/// If set to non-zero will be called after delay cycles elapsed with provided message.
	override void handleUpdateQuery(ref size_t message, ref ulong delay)
	{
		ulong diff = _dcpu.regs.cycles - regs.initialCycles;
		ulong totalTicks = diff / regs.tickPeriod;
		if (totalTicks > regs.ticks)
		{
			foreach(i; 0..totalTicks - regs.ticks)
			{
				regs.inc!"ticks";
				if (regs.interruptMessage > 0)
				{
					triggerInterrupt(_emulator.dcpu, regs.interruptMessage);
				}
			}
		}

		delay = regs.tickPeriod;
	}

	/// Returns: 32 bit word identifying the hardware id.
	override uint hardwareId() @property
	{
		return 0x12d0b402;
	}

	/// Returns: 16 bit word identifying the hardware version.
	override ushort hardwareVersion() @property
	{
		return 1;
	}

	/// Returns: 32 bit word identifying the manufacturer
	override uint manufacturer() @property
	{
		return 0;
	}

	override void commitFrame(ulong frameNumber)
	{
		regs.commitFrame(frameNumber);
	}

	override void discardFrame()
	{
		regs.discardFrame();
	}

	override void undoFrames(ulong numFrames)
	{
		regs.undoFrames(numFrames);
	}

	override void discardUndoStack()
	{
		regs.discardUndoStack();
	}

	override size_t undoStackSize() @property
	{
		return regs.undoStackSize;
	}
}