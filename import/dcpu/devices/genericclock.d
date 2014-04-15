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

@trusted nothrow:

/++
 + Generic Clock (compatible) v1.0
 + See 'docs/generic clock.txt' for specification.
 +/

class GenericClock(Cpu) : IDevice!Cpu
{
protected:
	Cpu* _dcpu;
	Emulator!Cpu _emulator;
	ulong initialCycles;
	ushort ticks;
	ushort divider;
	ulong tickPeriod;
	ushort interruptMessage;

public:
	/// Saves dcpu reference internally for future use.
	override void attachEmulator(Emulator!Cpu emulator)
	{
		_emulator = emulator;
		_dcpu = &emulator.dcpu;

		ticks = 0;
		divider = 0;
		tickPeriod = 0;
		interruptMessage = 0;
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
				if (divider != 0)
				{
					_dcpu.updateQueue.removeQueries(this);
				}

				divider = bRegister;

				if (divider != 0)
				{
					tickPeriod = cast(ulong)(_dcpu.clockSpeed / (60.0 / divider));
					_dcpu.updateQueue.addQuery(this, tickPeriod, 0);
				}
				ticks = 0;
				initialCycles = _dcpu.regs.cycles;
				return 0;
			case 1:
				_dcpu.regs.b = ticks;
				return 0;
			case 2:
				interruptMessage = bRegister;
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
		ulong diff = _dcpu.regs.cycles - initialCycles;
		ulong totalTicks = diff / tickPeriod;
		if (totalTicks > ticks)
		{
			foreach(i; 0..totalTicks-ticks)
			{
				++ticks;
				if (interruptMessage > 0)
				{
					triggerInterrupt(_emulator.dcpu, interruptMessage);
				}
			}
		}

		delay = tickPeriod;
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
		
	}

	override void discardFrame()
	{

	}

	override void undoFrames(ulong numFrames)
	{

	}

	override void discardUndoStack()
	{
		
	}
}