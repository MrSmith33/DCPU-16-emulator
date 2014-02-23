/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.dcpu;

import std.algorithm : fill;

import dcpu.devices.idevice;
import dcpu.interruptqueue;
import dcpu.updatequeue;

@safe nothrow:

/// DCPU-16 memory and registers storage.
struct Dcpu
{
	ushort[8]	reg;
	ushort		pc;
	ushort		sp;
	ushort		ex;
	ushort		ia;

	ulong cycles; /// cycles done by DCPU.

	ushort[0x10000] mem;

	bool queueInterrupts = false;
	InterruptQueue intQueue;

	UpdateQueue* updateQueue;
	
	private ushort nextHardwareId = 0;
	IDevice[ushort] devices;

	bool isBurning = false;

	ushort numDevices() @property @trusted
	{
		return cast(ushort)devices.length;
	}

	ushort attachDevice(IDevice device) // TODO: checks
	{
		devices[nextHardwareId] = device;
		return nextHardwareId++;
	}
}

/// Resets dcpu to its initial state.
void reset(ref Dcpu data)
{
	data.reg = [0, 0, 0, 0, 0, 0, 0, 0];
	data.pc = 0;
	data.sp = 0;
	data.ex = 0;
	data.ia = 0;

	data.cycles = 0;

	data.queueInterrupts = false;
	data.intQueue.clear();


	data.devices = null;
	data.nextHardwareId = 0;

	data.isBurning = false;

	fill!(ushort[], ushort)(data.mem, 0u);
}