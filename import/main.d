module main;

import std.stdio;
import dcpu;

void main()
{
	//auto inter = new DcpuInterpreter();
	//inter.data.reg[0] = 0x80FF;
	//inter.data.mem[0..3] = [0x7c01, 0xfff9,0xc409];
	//inter.step();

	writefln("res %x",cast(uint)(0x0-0xFFFF)>>16);
}