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
import dcpu.deviceproxy;

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

struct DebugDcpu
{
	//alias Cpu = typeof(this);

	auto regs = ObservableRegisters!(DcpuRegisters, 2)(0);

	auto mem = ObservableMemory!(ushort[0x10000], 2)(0);

	uint clockSpeed = 100_000; //Hz

	InterruptQueue intQueue;
	UpdateQueue!DebugDcpu* updateQueue;
	IDevice!DebugDcpu[ushort] devices;
	private ushort nextHardwareId = 0;

	bool isBurning = false;
	bool isRunning = false;

	size_t imageSize;

	ushort numDevices() @property @trusted
	{
		return cast(ushort)devices.length;
	}

	ushort attachDevice(IDevice!DebugDcpu device) // TODO: checks
	{
		devices[nextHardwareId] = device;
		return nextHardwareId++;
	}
}

/*/// DCPU-16 memory and registers storage.
struct FastDcpu
{
	//alias Cpu = typeof(this);

	uint clockSpeed = 100_000; //Hz

	DcpuRegisters regs;

	ushort[0x10000] mem;

	InterruptQueue intQueue;

	UpdateQueue!FastDcpu* updateQueue;
	
	private ushort nextHardwareId = 0;
	IDevice!FastDcpu[ushort] devices;

	bool isBurning = false;
	bool isRunning = false;

	ushort numDevices() @property @trusted
	{
		return cast(ushort)devices.length;
	}

	ushort attachDevice(IDevice!FastDcpu device) // TODO: checks
	{
		devices[nextHardwareId] = device;
		return nextHardwareId++;
	}
}

/// Resets dcpu to its initial state.
void reset(ref FastDcpu data)
{
	data.array[] = 0;

	data.cycles = 0;
	data.instructions = 0;

	data.queueInterrupts = false;
	data.intQueue.clear();


	data.devices = null;
	data.nextHardwareId = 0;

	data.isBurning = false;

	fill!(ushort[], ushort)(data.mem, 0u);
}*/

void reset(ref DebugDcpu dcpu)
{
	dcpu.regs.observableArray[] = 0;
	dcpu.regs.observer.discardUndoStack();
	dcpu.regs.observer.discardFrame();

	dcpu.intQueue.clear();

	dcpu.devices = null;
	dcpu.nextHardwareId = 0;

	dcpu.isBurning = false;

	dcpu.mem.observableArray[] = 0;
	dcpu.mem.observer.discardUndoStack();
	dcpu.mem.observer.discardFrame();
}