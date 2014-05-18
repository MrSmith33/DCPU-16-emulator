/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.undoproxy;

//version = debug_observer;

import std.algorithm : sort, SwapStrategy, filter, map;
import std.array : array, RefAppender, Appender, appender;
import std.range : iota, take, popFrontN;
import std.bitmanip : append, peek;
version(debug_observer) import std.stdio;
import std.string : format;
import dcpu.groupsequence;

@trusted:

/// Needs ubyte[] observableArray; in insertion context to work.
mixin template UndoHelper()
{
	enum maxUndoSeqLength = 128;

	// Saves initial value of ubyte at index
	ubyte[size_t] frameUndoMap;

	Appender!(ubyte[]) undoStack;

	bool hasUncommitedChanges() @property
	{
		return frameUndoMap.length > 0;
	}

	void discardFrame()
	{
		frameUndoMap = null;
	}

	void commitFrame(ulong frameNumber)
	{
		auto changeGroups = frameUndoMap
							.keys()
							.sort!("a<b", SwapStrategy.stable)
							.filter!(a => frameUndoMap[a] != observableArray[a])
							.groupSequence!"b-a == 1"; //[0] position, [1] count

		undoStack.append!ubyte(0); // Frame separator;

		foreach(changeGroup; changeGroups)
		{
			auto position = changeGroup[0];

			size_t len = changeGroup[1];

			if (len <= maxUndoSeqLength)
			{
				undoStack ~= iota(position, position+len).map!(a => frameUndoMap[a]);
				undoStack.append!uint(position);
				undoStack.append!ubyte(cast(ubyte)len);
			}
			else
			{
				auto undoElements = iota(position, position+len).map!(a => frameUndoMap[a]);

				while (!undoElements.empty)
				{
					auto numElementsToAdd = undoElements.length > maxUndoSeqLength ?
											maxUndoSeqLength : undoElements.length;
					
					undoStack ~= undoElements.take(numElementsToAdd);
					undoStack.append!uint(position);
					undoStack.append!ubyte(cast(ubyte)numElementsToAdd);

					undoElements.popFrontN(numElementsToAdd);

					position += numElementsToAdd;
				}
			}
		}

		discardFrame();
	}

	private void addUndoAction(size_t pos, ubyte[] data)
	in
	{
		assert((pos + data.length - 1) < observableArray.length);
	}
	body
	{
		foreach(index; pos..pos + data.length)
		{
			if (index !in frameUndoMap && observableArray[index] != data[index - pos])
			{
				frameUndoMap[index] = observableArray[index];
			}
		}
	}

	void discardUndoStack()
	{
		undoStack.shrinkTo(0);
	}

	void undoFrames(ulong numFrames = 1)
	{
		ulong framesUndone = 0;

		while(undoStackSize > 0 && framesUndone < numFrames)
		{
			while(undoStackSize > 0)
			{
				// extract undo data length
				ubyte length = undoStack.data.peek!ubyte(undoStackSize - 1);

				// frame end found
				if (length == 0)
				{
					undoStack.shrinkTo(undoStackSize - 1);
					break;
				}

				// extract target positon
				size_t position = undoStack.data.peek!uint(undoStackSize - 5);

				// extract undo data
				auto undoData = undoStack.data[$ - (5 + length)..$ - 5];

				// Make undo
				observableArray[position..position + undoData.length] = undoData;

				// Shrink undo stack
				auto shrinkDelta = ubyte.sizeof + uint.sizeof + length;
				undoStack.shrinkTo(undoStackSize - shrinkDelta);
			}

			++framesUndone;
			version(debug_observer) writefln("Undo stack %s\n", undoStack.data);
		}
	}

	size_t undoStackSize() @property
	{
		return undoStack.data.length;
	}
}

struct UndoableStruct(Struct, ArrayElement)
{
	union
	{
		Struct data;
		ubyte[Struct.sizeof] observableArray;
	}

	mixin UndoHelper;

	void reset()
	{
		observableArray[] = 0;
		discardFrame();
		discardUndoStack();
	}

	auto opMemberAssign(string member, string op, T = ubyte)(T value = 1)
	{
		alias Member = typeof(__traits(getMember, data, member));

		return opDispatch!(member)(
			cast(Member)(mixin("opDispatch!(member)() "~op~" value"))
		);
	}

	alias inc(string member) = opMemberAssign!(member, "+");
	alias dec(string member) = opMemberAssign!(member, "-");

	// setter
	auto opDispatch(string member, T)(T newValue)
	{
		alias Member = typeof(__traits(getMember, data, member));

		auto value = __traits(getMember, data, member);

		if (value == newValue) return value;

		Member newValueCasted = cast(Member)newValue;

		addUndoAction(
			__traits(getMember, data, member).offsetof,
			*(cast(ubyte[Member.sizeof]*)&newValueCasted)
		);

		__traits(getMember, data, member) = newValueCasted;

		return __traits(getMember, data, member);
	}

	// getter
	auto opDispatch(string member)()
	{
		return __traits(getMember, data, member);
	}

	auto opIndex(size_t index)
	{
		return (cast(ArrayElement[])observableArray)[index];
	}

	void opSliceAssign(ArrayElement[] data, size_t i, size_t j)
	in
	{
		assert(j <= (cast(ArrayElement[])observableArray).length);
		assert(i < j);
		assert(data.length == j - i, format("Arrays have different sizes %s and %s", data.length, j - i));
	}
	body
	{

		addUndoAction(i * ArrayElement.sizeof, cast(ubyte[])data);

		(cast(ArrayElement[])observableArray)[i..j] = data;
	}

	ArrayElement opIndexAssign(ArrayElement data, size_t index)
	{
		assert(index <= (cast(ArrayElement[])observableArray).length);

		addUndoAction(index * ArrayElement.sizeof, *(cast(ubyte[ArrayElement.sizeof]*)&data));

		return (cast(ArrayElement[])observableArray)[index] = data;
	}
}