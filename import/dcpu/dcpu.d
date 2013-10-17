module dcpu.dcpu;

/// DCPU-16 memory and registers storage.
struct DcpuData
{
	ushort[8]	reg;
	ushort		pc;
	ushort		sp;
	ushort		ex;
	ushort		ia;

	ushort[0x10000] mem;
}

/// Resets dcpu to its initial state.
void reset(DcpuData data)
{
	data.reg = [0, 0, 0, 0, 0, 0, 0, 0];
	data.pc = 0;
	data.sp = 0;
	data.ex = 0;
	data.ia = 0;

	fill!(ushort[], ushort)(data.mem, 0u);
}