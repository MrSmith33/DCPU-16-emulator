module dcpu;

import std.algorithm : fill;
import std.stdio;

struct DcpuData
{
	ushort[8]	reg;
	ushort		pc;
	ushort		sp;
	ushort		ex;
	ushort		ia;

	ushort[0x10000] mem;
}

void reset(DcpuData data)
{
	data.reg = [0, 0, 0, 0, 0, 0, 0, 0];
	data.pc = 0;
	data.sp = 0;
	data.ex = 0;
	data.ia = 0;

	fill!(ushort[], ushort)(data.mem, 0u);
}

static ushort[0x20] literals =
	[0xFFFF, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
	 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
	 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
	 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E];

ushort* getOperand(bool isA)(ref DcpuData d, ushort val)
in
{
	assert(val < 0x40, "operand must be lower than 0x40");
	static if (isA)
		assert(val <= 0x1f);
}
body
{
	switch(val)
	{
		case 0x00: .. case 0x07:
			return &d.reg[val];
		case 0x08: .. case 0x0f:
			return &d.mem[d.reg[val & 7]];
		case 0x10: .. case 0x17:
			return &d.mem[(d.reg[val & 7] + d.mem[d.pc++]) & 0xffff];
		case 0x18:
			static if (isA)
				return &d.mem[d.sp++];
			else
				return &d.mem[--d.sp];
		case 0x19:
			return &d.mem[d.sp];
		case 0x1a:
			return &d.mem[d.sp + d.pc++];
		case 0x1b:
			return &d.sp;
		case 0x1c:
			return &d.pc;
		case 0x1d:
			return &d.ex;
		case 0x1e:
			return &d.mem[d.mem[d.pc++]];
		case 0x1f:
			return &d.mem[d.pc++];
		default:
			return &literals[val & 0x1F];
	}
}

class DcpuInterpreter
{
	DcpuData data;
	size_t cycles; /// cycles done by DCPU

	void step() /// Perform next instruction
	{
		ushort instruction = data.mem[data.pc++];

		if ((instruction & 0x1F) != 0) //basic
		{
			basicInstruction(instruction);
		}
		else //special
		{

		}
	}

	void basicInstruction(ushort instruction)
	{
		ushort a = *getOperand!true(data, instruction >> 10);
		writeln("A: ", a);
		ushort destinationType = (instruction >> 5) & 0x1F;
		ushort* destination = getOperand!false(data, destinationType);
		ushort  b = *destination;
		writeln("B: ", b);

		uint result;

		final switch(instruction & 0x1F)
		{
			case 0x00: assert(false);
			case 0x01: result = a; break;
			case 0x02: result = a + b; data.ex = result >> 16; break;
			case 0x03: assert(false);
			case 0x04: assert(false);
			case 0x05: assert(false);
			case 0x06: assert(false);
			case 0x07: assert(false);
			case 0x08: result = a == 0 ? 0 : b % a; break;
			case 0x09: result = a == 0 ? 0 : cast(short)b % cast(short)a; break;
			case 0x0A: result = a & b; break;
			case 0x0B: result = a | b; break;
			case 0x0C: result = a ^ b; break;
			case 0x0D: result = b >> a; data.ex = ((b<<16)>>a) & 0xffff; break;
			case 0x0E: result = cast(short)b >>> a;
						data.ex = ((b<<16)>>>a) & 0xffff; break;
			case 0x0F: result = b << a; data.ex = ((b<<a)>>16) & 0xffff; break; // SHL
			case 0x10: assert(false);
			case 0x11: assert(false);
			case 0x12: assert(false);
			case 0x13: assert(false);
			case 0x14: assert(false);
			case 0x15: assert(false);
			case 0x16: assert(false);
			case 0x17: assert(false);
			case 0x18: assert(false);
			case 0x19: assert(false);
			case 0x1A: assert(false);
			case 0x1B: result = b - a + data.ex;
						if (ushort over = result >> 16)
							data.ex = over == 0xFFFF ? 0xFFFF : 1;
						break;
			case 0x1C: assert(false);
			case 0x1D: assert(false);
			case 0x1E: result = a; ++data.reg[6]; ++data.reg[7]; break;
			case 0x1F: result = a; --data.reg[6]; --data.reg[7]; break;
		}

		if (destinationType < 0x1F)
		{
			writeln(a >> b);
			writeln("Res: ", result);
			*destination = result & 0xFFFF;
		}
		else
			writeln("Attempting to write to a literal");
	}

	void skip()
	{

	}
}