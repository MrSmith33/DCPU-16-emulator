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
	enum clockSpeed = 100_000; //Hz

	union
	{
		ushort[12]	reg;
		struct
		{
			ushort reg_a;  //0
			ushort reg_b;  //1
			ushort reg_c;  //2
			ushort reg_x;  //3
			ushort reg_y;  //4
			ushort reg_z;  //5
			ushort reg_i;  //6
			ushort reg_j;  //7
			ushort reg_sp; //8
			ushort reg_pc; //9
			ushort reg_ex; //10
			ushort reg_ia; //11
		}
	}

	ulong cycles; /// cycles done by DCPU.
	ulong instructions; /// instructions done by DCPU.

	ushort[0x10000] mem;

	bool queueInterrupts = false;
	InterruptQueue intQueue;

	UpdateQueue* updateQueue;
	
	private ushort nextHardwareId = 0;
	IDevice[ushort] devices;

	bool isBurning = false;
	bool isRunning = false;

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
	data.reg[] = 0;

	data.cycles = 0;
	data.instructions = 0;

	data.queueInterrupts = false;
	data.intQueue.clear();


	data.devices = null;
	data.nextHardwareId = 0;

	data.isBurning = false;

	fill!(ushort[], ushort)(data.mem, 0u);
}