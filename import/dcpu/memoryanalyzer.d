/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.memoryanalyzer;

import std.array;
import std.algorithm : sort, find;
import std.string : format;
import std.stdio;

import dcpu.dcpu;
import dcpu.constants;
import dcpu.dcpuinstruction;
import dcpu.dcpuemulation;

class MemoryAnalyzer(Cpu)
{
protected:
	Cpu* _dcpu;

public:

	MemoryMap memoryMap;

	this(Cpu* dcpu)
	{
		_dcpu = dcpu;
	}

	// PC "jumps" to 0 at cpu start
	enum ushort defaultEntryPoint = 0;

	MemoryBlock* blockAtPos(ushort position)
	{
		auto blocks = find!"a.position <= b && b < a.position + a.length"
				(memoryMap.blocks, position);
		
		if (blocks.length) return blocks[0];
		
		return null;
	}

	void buildMemoryMap()
	{
		auto processQueue = Appender!(Transition*[])([]); // control flow transitions (JMP and set, add, sub pc)

		processQueue ~= new Transition(0, defaultEntryPoint, TransitionType.jump, false);

		void processEntryPoint(Transition* transition)
		{
			ushort entryPoint = transition.to;

			// Transition to an existing block
			if (auto blockFound = blockAtPos(entryPoint))
			{
				blockFound.transitionsIn ~= transition;
				transition.toBlock = blockFound;
				return;
			}

			auto block = new MemoryBlock(entryPoint);
			block.type = BlockType.code;
			memoryMap.blocks ~= block;
			transition.toBlock = block;

			writefln("New block at %04x", entryPoint);

			ushort pointer = entryPoint;
			Instruction instr;

			bool inCondition = false;

			while (pointer >= entryPoint)
			{
				// No place to expand, other (code) block detected
				if (auto blockFound = blockAtPos(pointer))
				{
					blockFound.transitionsIn ~= transition;
					writefln("Block ended [No space] %04x..%04x\n",
						blockFound.position, blockFound.position+blockFound.length-1);
					return;
				}

				instr = fetchAt(*_dcpu, pointer);

				void onBlockEnd()
				{
					block.length = pointer + instr.size - block.position;
					block.lastInstr = pointer;
					writefln("Block ended [Jump] %04x..%04x\n",
						block.position, block.position+block.length-1);
				}

				if (instr.operands == 2 && instr.operandB == 0x1c/*PC*/)
				{
					// Unconditional branching 
					if (instr.opcode == SET) // temp TODO: add, sub with literals
					{
						if (isOperandImmediate[instr.operandA])
						{
							ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
							ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

							// outcoming transition
							auto newTransition = new Transition(pointer, transitionTo,
								TransitionType.jump, inCondition, block);
							
							block.transitionsFrom ~= newTransition;
							processQueue ~= newTransition;

							writeln(*newTransition);
						}

						if (!inCondition)
						{
							onBlockEnd();
							return;
						}
					}
				}
				else if (instr.operands == 1 && isOperandImmediate[instr.operandA])
				{
					if (instr.opcode == JSR)
					{
						ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
						ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

						// outcoming transition
						auto newTransition = new Transition(pointer, transitionTo,
							TransitionType.call, inCondition, block);
						
						block.transitionsFrom ~= newTransition;
						processQueue ~= newTransition;

						writeln(*newTransition);
						
					}
					else if(instr.opcode == IAS)
					{
						ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
						ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

						// outcoming transition. Indirect
						auto newTransition = new Transition(pointer, transitionTo,
							TransitionType.interrupt, inCondition, block);
						
						block.transitionsFrom ~= newTransition;
						processQueue ~= newTransition;
						
						writeln(*newTransition);
					}
				}
				else if (!isValidInstruction(instr))
				{
					writefln("Block ended [Invalid found] %04x..%04x\n",
						block.position, block.position+block.length-1);
					return;
				}
				
				inCondition = isConditionalInstruction(instr);
				pointer += instr.size;
				block.length += instr.size;
			}
		}

		uint iterations;
		while(!processQueue.data.empty && iterations < 1000)
		{
			Transition* trans = processQueue.data[$-1];

			memoryMap.transitions ~= trans;

			processQueue.shrinkTo(processQueue.data.length-1);

			processEntryPoint(trans);
		}

		// sort blocks and transitions.
		memoryMap.transitions.sort!"a.to < b.to";
		memoryMap.blocks.sort!"a.position < b.position";

		uint[TransitionType.max+1] transitionTypeCounters;
		foreach(i, transition; memoryMap.transitions)
		{
			transition.index = i;
			transition.typeIndex = transitionTypeCounters[transition.type]++;
		}

		foreach(i, block; memoryMap.blocks)
		{
			block.index = i;
		}
	}
}

enum BlockType
{
	data,
	code,
	empty
}

enum TransitionType
{
	call,
	jump,
	interrupt
}

struct Transition
{
	ushort from;
	ushort to;
	TransitionType type;
	bool conditional;
	MemoryBlock* fromBlock;
	MemoryBlock* toBlock;
	size_t index; // index in transition list. Used for setting labels
	size_t typeIndex; // index in transition list of specific type.

	string toString()
	{
		return format("Transition %04x -> %04x %s from %04x to %04x",
			from, to, type, fromBlock ? fromBlock.position : 0, toBlock ? toBlock.position : 0);
	}

}

struct MemoryBlock
{
	size_t position; // in memory
	size_t lastInstr; // position
	size_t length; // in words;
	Transition*[] transitionsIn; // jumps made to this block
	Transition*[] transitionsFrom; // jumps from this block
	BlockType type;
	size_t index; // index in block list. Used for setting labels

	string toString()
	{
		return format("[%3s] %04x..%s %s", index, position, length == 0 ? "Invalid" : format("%04x", lastInstr), type);
	}
}

struct MemoryMap
{
	Transition*[] transitions;
	MemoryBlock*[] blocks;
}