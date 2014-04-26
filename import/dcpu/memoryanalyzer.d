/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.memoryanalyzer;

import std.array;
import std.algorithm : sort, find;
import std.conv : to;
import std.string : format;
import std.stdio : writeln, writefln;

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

	Label* labelAt(ushort position, LabelType type)
	{
		auto labels = find!"a.position == b"(memoryMap.labels, position);

		if (labels.length)
		{
			if (labels[0].type == LabelType.label && type == LabelType.subroutine)
				labels[0].type = type;

			return labels[0];
		}

		auto newLabel = new Label(position, type);

		writefln("New %s label at %04x ", type, position);

		memoryMap.labels ~= newLabel;

		return newLabel;
	}

	void buildMemoryMap()
	{
		auto processQueue = Appender!(Transition*[])([]); // control flow transitions (JMP and set, add, sub pc)

		processQueue ~= new Transition(0,
			labelAt(defaultEntryPoint, LabelType.label),
			TransitionType.entry,
			false);

		void processTransition(Transition* transition)
		{
			ushort entryPoint = transition.target.position;

			// Transition to an existing block
			if (auto blockFound = blockAtPos(entryPoint))
			{
				blockFound.transitionsIn ~= transition;
				transition.toBlock = blockFound;
				return;
			}

			// New block
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

				// Get instruction at pointer
				instr = fetchAt(*_dcpu, pointer);

				void onBlockEnd()
				{
					block.length = pointer + instr.size - block.position;
					block.lastInstr = pointer;
					writefln("Block ended [Jump] %04x..%04x\n",
						block.position, block.position+block.length-1);
				}

				// Check instruction
				// If SET PC, literal that it is jump
				if (instr.operands == 2 && instr.operandB == 0x1c/*PC*/)
				{
					// Unconditional branching 
					if (instr.opcode == SET || instr.opcode == STI || instr.opcode == STD) // temp TODO: add, sub with literals
					{
						if (isOperandImmediate[instr.operandA])
						{
							ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
							ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

							// outcoming transition
							auto newTransition = new Transition(pointer,
								labelAt(transitionTo, LabelType.label),
								TransitionType.jump,
								inCondition,
								block);
							
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
				// If JSR that it is call
				else if (instr.operands == 1 && isOperandImmediate[instr.operandA])
				{
					if (instr.opcode == JSR)
					{
						ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
						ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

						// outcoming transition
						auto newTransition = new Transition(pointer,
							labelAt(transitionTo, LabelType.subroutine),
							TransitionType.call,
							inCondition,
							block);
						
						block.transitionsFrom ~= newTransition;
						processQueue ~= newTransition;

						writeln(*newTransition);
						
					}
					else if(instr.opcode == IAS)
					{
						ushort pc = cast(ushort)(pointer+1), sp = 0xFFFF; 
						ushort transitionTo = getOperandA(*_dcpu, instr.operandA, pc, sp).get();

						// outcoming transition. Indirect
						auto newTransition = new Transition(pointer,
							labelAt(transitionTo, LabelType.int_handler),
							TransitionType.intHandler,
							inCondition,
							block);
						
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
			
			if (trans.target.position == trans.from && trans.type != TransitionType.entry)
			{
				trans.target.type = LabelType.crash;
			}

			processTransition(trans);
		}

		// sort blocks and transitions.
		memoryMap.transitions.sort!"a.from < b.from";
		memoryMap.blocks.sort!"a.position < b.position";
		memoryMap.labels.sort!"a.position < b.position";

		foreach(i, transition; memoryMap.transitions)
		{
			transition.index = i;
		}

		foreach(i, block; memoryMap.blocks)
		{
			block.index = i;
		}

		uint[LabelType.max+1] labelCounters;
		Label*[][LabelType.max+1] typeLabels; // labels of the same type;
		
		foreach(label; memoryMap.labels)
		{
			label.index = labelCounters[label.type]++;
			typeLabels[label.type] ~= label;
			writeln(*label);
		}

		foreach(labelArray; typeLabels)
		{
			foreach(label; labelArray)
			{
				label.typeCount = labelArray.length;
			}
		}
	}
}


enum TransitionType
{
	call,
	jump,
	intHandler,
	entry
}

struct Transition
{
	ushort from;
	Label* target;
	TransitionType type;
	bool conditional;
	MemoryBlock* fromBlock;
	MemoryBlock* toBlock;
	size_t index; // index in transition list of specific type.

	string toString()
	{
		return format("Transition %04x -> %04x %s from %04x to %04x",
			from, target.position, type, fromBlock ? fromBlock.position : 0, toBlock ? toBlock.position : 0);
	}
}

enum LabelType
{
	subroutine,
	crash,
	label,
	int_handler,
	start
}

struct Label
{
	ushort position;
	LabelType type;
	size_t index;
	size_t typeCount; // Count of labels of the same type

	string toString()
	{
		if (typeCount == 1)
			return to!string(type);
		
		return format("%s_%s", type, index);
	}
}

enum BlockType
{
	data,
	code,
	empty
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
	Label*[] labels;
	MemoryBlock*[] blocks;
}