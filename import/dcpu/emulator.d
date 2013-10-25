module dcpu.emulator;

import dcpu.dcpu;

@safe nothrow:

/// Does actual interpreting of DCPU-16
public class Emulator
{
	Dcpu dcpu; /// data storage: memory, registers.
	size_t cycles; /// cycles done by DCPU.

	/// Performs next instruction
	void step()
	{
		ushort instruction = dcpu.mem[dcpu.pc++];

		if ((instruction & 0x1F) != 0) //basic
		{
			basicInstruction(instruction);
		}
		else //special
		{
			specialInstruction(instruction);
		}

		// Handle interrupts only when interrupt queuing is disabled.
		// It may be enabled by interrupt handler or manually in time critical code.
		if (!dcpu.queueInterrupts)
		{
			handleInterrupt();
		}
	}

	/// Adds interrupt with message 'message' to dcpu.intQueue or starts burning DCPU if queue grows bigger than 256
	void triggerInterrupt(ushort message)
	{
		if (dcpu.intQueue.isFull)
		{
			dcpu.isBurning = true;
		}
		else
		{
			dcpu.intQueue.add(message);
		}
	}

private:

	/// Performs basic instruction.
	void basicInstruction(ushort instruction)
	{
		ushort opcode = instruction & 0x1F;

		ushort a = *getOperand!true(instruction >> 10);

		ushort destinationType = (instruction >> 5) & 0x1F;
		ushort* destination = getOperand!false(destinationType);
		ushort  b = *destination;

		uint result;

		cycles += basicCycles[opcode];

		final switch (opcode)
		{
			case 0x00 : assert(false); // Special opcode. Execution never goes here.
			case 0x01 : result = a; break; // SET
			case 0x02 : result = b + a; dcpu.ex = result >> 16; break; // ADD
			case 0x03 : result = b - a; dcpu.ex = (a > b) ? 0xFFFF : 0; break; // SUB
			case 0x04 : result = b * a; dcpu.ex = result >> 16; break; // MUL
			case 0x05 : result = cast(short)a * cast(short)b; dcpu.ex = result >> 16; break; // MLI
			case 0x06 : if (a==0){dcpu.ex = 0; result = 0;}
						else {result = b/a; dcpu.ex = ((b << 16)/a) & 0xffff;} break; // DIV TODO:test
			case 0x07 : if (a==0){dcpu.ex = 0; result = 0;}
						else {
							result = cast(short)b/cast(short)a;
							dcpu.ex = ((b << 16)/a) & 0xffff;
						} break; // DVI TODO:test
			case 0x08 : result = a == 0 ? 0 : b % a; break; // MOD
			case 0x09 : result = a == 0 ? 0 : cast(short)b % cast(short)a; break; //MDI
			case 0x0A : result = a & b; break; // AND
			case 0x0B : result = a | b; break; // BOR
			case 0x0C : result = a ^ b; break; // XOR
			case 0x0D : result = b >> a; dcpu.ex = ((b<<16)>>a) & 0xffff; break; // SHR
			case 0x0E : result = cast(short)b >>> a;
						dcpu.ex = ((b<<16)>>>a) & 0xffff; break; // ASR
			case 0x0F : result = b << a; dcpu.ex = ((b<<a)>>16) & 0xffff; break; // SHL
			case 0x10 : if ((b & a)!=0) skip(); return; // IFB TODO:test
			case 0x11 : if ((b & a)==0) skip(); return; // IFC TODO:test
			case 0x12 : if (b == a) skip(); return; // IFE TODO:test
			case 0x13 : if (b != a) skip(); return; // IFE // IFN TODO:test
			case 0x14 : if (b > a) skip(); return; // IFG TODO:test
			case 0x15 : if (cast(short)b > cast(short)a) skip(); return; // IFA TODO:test
			case 0x16 : if (b < a) skip(); return; // IFL TODO:test
			case 0x17 : if (cast(short)b < cast(short)a) skip(); return; // IFU TODO:test
			case 0x18 : assert(false); // Invalid opcode
			case 0x19 : assert(false); // Invalid opcode
			case 0x1A : result = b + a + dcpu.ex;
						dcpu.ex = result >> 16 ? 1 : 0; break; // ADX
			case 0x1B : result = b - a + dcpu.ex; dcpu.ex = 0;
						if (ushort over = result >> 16)
							dcpu.ex = over == 0xFFFF ? 0xFFFF : 0x0001;
						break; // SBX
			case 0x1C : assert(false); // Invalid opcode
			case 0x1D : assert(false); // Invalid opcode
			case 0x1E : result = a; ++dcpu.reg[6]; ++dcpu.reg[7]; break; // STI
			case 0x1F : result = a; --dcpu.reg[6]; --dcpu.reg[7]; break; // STD
		}

		if (destinationType < 0x1F)
		{
			*destination = result & 0xFFFF;
		}
		//else Attempting to write to a literal
	}

	/// Performs special instruction.
	void specialInstruction(ushort instruction)
	{
		ushort* a = getOperand!true(instruction >> 10);

		ushort opcode = (instruction >> 5) & 0x1F;

		switch (opcode)
		{
			case 0x01 : push(dcpu.pc); dcpu.pc = *a; break; // JSR
			case 0x08 : triggerInterrupt(*a); break; // INT
			case 0x09 : *a = dcpu.ia; break; // IAG
			case 0x0a : dcpu.ia = *a; break; // IAS
			case 0x0b : dcpu.queueInterrupts = false;
						dcpu.reg[0] = pop();
						dcpu.pc = pop();
						break; // RFI
			case 0x0c : dcpu.queueInterrupts = *a > 0; break; // IAQ
			case 0x10 : *a = dcpu.numDevices; break; // HWN
			case 0x11 : queryHardwareInfo(*a); break; // HWQ
			case 0x12 : sendHardwareInterrupt(*a); break; // HWI
			default : assert(false);
		}
	}

	/// Pushes value onto stack increasing SP.
	void push(ushort value)
	{
		dcpu.mem[--dcpu.sp] = value;
	}

	/// Pops value from stack decreasing SP.
	ushort pop()
	{
		return dcpu.mem[++dcpu.sp];
	}

	/// Sets A, B, C, X, Y registers to information about hardware deviceIndex
	void queryHardwareInfo(ushort deviceIndex)
	{
		if (auto device = deviceIndex in dcpu.devices)
		{
			cast(uint[1])dcpu.reg[0..2] = device.hardwareId;
			dcpu.reg[2] = device.hardwareVersion;
			cast(uint[1])dcpu.reg[3..5] = device.manufacturer;
		}
	}

	/// Sends an interrupt to hardware deviceIndex
	void sendHardwareInterrupt(ushort deviceIndex)
	{
		if (auto device = deviceIndex in dcpu.devices)
		{
			cycles += device.handleInterrupt(this);
		}
	}

	/// Handles interrupt from interrupt queue if IA != 0 && intQueue.length > 0
	void handleInterrupt()
	{
		if (dcpu.intQueue.size == 0) return;

		ushort message = dcpu.intQueue.take();

		if (dcpu.ia != 0)
		{
			dcpu.queueInterrupts = true;

			push(dcpu.pc);
			push(dcpu.reg[0]);

			dcpu.pc = dcpu.ia;
			dcpu.reg[0] = message;
		}
	}

	/++
	+ Skips instructions if conditional opcode was failed.
	+
	+ The conditional opcodes take one cycle longer to perform if the test fails.
  	+ When they skip a conditional instruction, they will skip an additional
  	+ instruction at the cost of one extra cycle. This continues until a non-
  	+ conditional instruction has been skipped. This lets you easily chain
  	+ conditionals. Interrupts are not triggered while the DCPU-16 is skipping.
	+/
	void skip()
	{
		ushort opcode;
		ushort instr;

		do
		{
			instr = dcpu.mem[dcpu.pc++];
			opcode = instr & 0x1f;

			getOperand!true(instr >> 10); // TODO: optimize skipping
			getOperand!false((instr >> 5) & 0x1F);

			++cycles;
		}
		while (opcode >= 0x10 && opcode <= 0x17);
	}

	/// Resets dcpu state and interpreter state to their initial state.
	void reset()
	{
		dcpu.reset();
		cycles = 0;
	}

	/// Extracts operand from an instruction
	ushort* getOperand(bool isA)(ushort instr)
	in
	{
		assert(instr <= 0x3f, "operand must be lower than 0x40");
		static if (!isA)
			assert(instr <= 0x1f);
	}
	body
	{
		alias dcpu d;
		switch(instr)
		{
			case 0x00: .. case 0x07:
				return &d.reg[instr];
			case 0x08: .. case 0x0f:
				return &d.mem[d.reg[instr & 7]];
			case 0x10: .. case 0x17:
				++cycles;
				return &d.mem[(d.reg[instr & 7] + d.mem[d.pc++]) & 0xffff];
			case 0x18:
				static if (isA)
					return &d.mem[d.sp++];
				else
					return &d.mem[--d.sp];
			case 0x19:
				return &d.mem[d.sp];
			case 0x1a:
				++cycles;
				return &d.mem[d.sp + d.pc++];
			case 0x1b:
				return &d.sp;
			case 0x1c:
				return &d.pc;
			case 0x1d:
				return &d.ex;
			case 0x1e:
				++cycles;
				return &d.mem[d.mem[d.pc++]];
			case 0x1f:
				++cycles;
				return &d.mem[d.pc++];
			default:
				return &literals[instr & 0x1F];
		}
	}
}

/// Table of literal values which may be stored in 'a' operand.
private static ushort[0x20] literals =
	[0xFFFF, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
	 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
	 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
	 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E];

/// Table of basic instructions cost.
private static immutable ubyte[] basicCycles = 
	[0, 1, 2, 2, 2, 2, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1,
	 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 3, 3, 0, 0, 2, 2];

/// Table of special instructions cost.
private static immutable ubyte[] specialCycles = 
	[0, 3, 0, 0, 0, 0, 0, 0, 4, 1, 1, 3, 2, 0, 0, 0,
	 2, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

unittest
{

}