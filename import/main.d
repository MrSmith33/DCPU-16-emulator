module main;

import std.stdio;
import dcpu.dcpu;
import dcpu.emulator;

void main()
{
	Emulator em = new Emulator();
	em.dcpu.mem[0..48] = 
	[0x7fc1, 0x1234, 0x0030, 0xc3c2, 0x0031, 0x77c1, 0x0032, 0x7fc1,
	 0x1234, 0x0033, 0x83c2, 0x0033, 0x77c1, 0x0034, 0x7fc3, 0x1234,
	 0x0035, 0x77c1, 0x0036, 0x7fc1, 0x1234, 0x0037, 0x7fc3, 0x0dea,
	 0x0037, 0x77c1, 0x0038, 0x7fc1, 0x1234, 0x0039, 0x8fc4, 0x0039,
	 0x77c1, 0x003a, 0x83c1, 0x003b, 0x8fc4, 0x003b, 0x77c1, 0x003c,
	 0x7fc1, 0x1234, 0x003d, 0x7fc5, 0xfffe, 0x003d, 0x77c1, 0x003e, ];
	 foreach(_;0..20) em.step();

	writeln(em.dcpu.mem.length);
	printMem(48, 63, 8, em.dcpu);
	writeln("Cycles: ", em.cycles);
	
	//writefln("%x",(cast(short)0x1234*cast(short)-2));
}

void printMem(ushort start, ushort end, ushort padding, ref Dcpu dcpu)
{
	for(uint i = start; i < end; i += padding)
	{
		writef("%04x: ", i);
		for(uint pad = 0; pad < padding; ++pad)
		{
			if (end <= i+pad)
				writef("%04x ", 0);			
			else
				writef("%04x ", dcpu.mem[i+pad]);
		}
		writeln;
	}
}