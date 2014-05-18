/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/


module dcpu.dcpu;

import std.algorithm : fill;

import dcpu.devices.idevice;
import dcpu.ringbuffer;
import dcpu.updatequeue;
import dcpu.undoproxy;

@safe:

struct DcpuRegisters
{
	union
	{
		ushort[12] array;
		struct
		{
			ushort a;  //0
			ushort b;  //1
			ushort c;  //2
			ushort x;  //3
			ushort y;  //4
			ushort z;  //5
			ushort i;  //6
			ushort j;  //7
			ushort sp; //8
			ushort pc; //9
			ushort ex; //10
			ushort ia; //11
		}
	}

	ulong cycles; /// cycles done by DCPU.
	ulong instructions; /// instructions done by DCPU.

	bool queueInterrupts = false;
}

struct DcpuMemory
{
	ushort[0x10000] mem;
}

struct Dcpu
{
	UndoableStruct!(DcpuRegisters, ushort) regs;
	UndoableStruct!(DcpuMemory, ushort) mem;

	uint clockSpeed = 100_000; //Hz

	RingBuffer!(ushort, 256) intQueue;
	UpdateQueue!Dcpu* updateQueue;
	IDevice!Dcpu[ushort] devices;
	private ushort nextHardwareId = 0;

	bool isBurning = false;
	bool isRunning = false;

	size_t imageSize;

	ushort numDevices() @property @trusted
	{
		return cast(ushort)devices.length;
	}

	ushort attachDevice(IDevice!Dcpu device) // TODO: checks
	{
		devices[nextHardwareId] = device;
		return nextHardwareId++;
	}

	void reset()
	{
		regs.reset();
		mem.reset();

		intQueue.clear();

		devices = null;
		nextHardwareId = 0;

		isBurning = false;
		updateQueue.queries = null;
	}
}

