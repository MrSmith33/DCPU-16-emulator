module dcpu.dcpu;

import std.algorithm : fill;

import dcpu.devices.idevice;

@safe nothrow:

/// DCPU-16 memory and registers storage.
struct Dcpu
{
	ushort[8]	reg;
	ushort		pc;
	ushort		sp;
	ushort		ex;
	ushort		ia;

	ushort[0x10000] mem;
	
	private nextHardwareId = 0;
	IDevice[ushort] devices;

	ushort attachDevice(IDevice device)
	{
		devices[nextHardwareId] = device;
		return nextHardwareId++;
	}
}

/// Resets dcpu to its initial state.
void reset(Dcpu data)
{
	data.reg = [0, 0, 0, 0, 0, 0, 0, 0];
	data.pc = 0;
	data.sp = 0;
	data.ex = 0;
	data.ia = 0;

	fill!(ushort[], ushort)(data.mem, 0u);
}