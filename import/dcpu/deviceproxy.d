/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.deviceproxy;

//version = debug_observer;

import std.algorithm : sort, SwapStrategy, filter, map;
import std.array : array, RefAppender, Appender, appender;
import std.range : iota, take, popFrontN;
import std.bitmanip : append, peek;
version(debug_observer) import std.stdio;
import std.string : format;
import dcpu.groupsequence;

template addressSpaceType(ubyte addressSpaceBytes)
{
	static if (addressSpaceBytes == 1)
		alias addressSpaceType = ubyte;
	else static if (addressSpaceBytes == 2)
		alias addressSpaceType = ushort;
	else static if (addressSpaceBytes > 2 && addressSpaceBytes < 5)
		alias addressSpaceType = uint;
	else static if (addressSpaceBytes > 4)
		alias addressSpaceType = ulong;
}

struct UndoObserver(ubyte addressSpaceBytes)
{
	ubyte[] observableArray;

	this(ubyte[] observableArray)
	{
		this.observableArray = observableArray;
	}

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

		undoStack.append!ubyte(0); // Frame bottom;

		foreach(changeGroup; changeGroups)
		{
			auto position = changeGroup[0];
			version(debug_observer) writeln(position);
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
					version(debug_observer) writefln("Add undo pack [%s] len(%s) %s\n", position, numElementsToAdd, undoElements.length);

					position += numElementsToAdd;
				}
			}
		}

		version(debug_observer) writefln("Undo stack %s\n", undoStack.data);

		discardFrame();
	}

	private void addUndoAction(size_t pos, ubyte[] data)
	{
		version(debug_observer) writefln("change to %s at %s", data, pos);
		assert((pos + data.length - 1) < observableArray.length);

		foreach(index; pos..pos + data.length)
		{
			if (index !in frameUndoMap && observableArray[index] != data[index - pos])
			{
				//version(debug_observer) writefln("Registered change [%s] %s -> %s", index, observableArray[index], data[index - pos]);
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
		auto stackSize = undoStack.data.length;
		ulong framesUndone = 0;

		while(stackSize > 0 && framesUndone < numFrames)
		{
			while(stackSize > 0)
			{
				// extract undo data length
				ubyte length = undoStack.data.peek!ubyte(stackSize - 1);

				// frame end found
				if (length == 0)
				{
					undoStack.shrinkTo(stackSize - 1);
					--stackSize;
					break;
				}

				// extract target positon
				size_t position = undoStack.data.peek!uint(stackSize - 5);

				// extract undo data
				auto undoData = undoStack.data[$ - (5 + length)..$ - 5];
				version(debug_observer) writefln("UndoPack [%s..%s] %s l%s %s at [%s]\n", stackSize - (5 + length), stackSize - 5, undoStack.data[$-5..$], stackSize, undoData, position);
				// Make undo
				observableArray[position..position+undoData.length] = undoData;

				// Shrink undo stack
				auto shrinkDelta = ubyte.sizeof + uint.sizeof + length;
				undoStack.shrinkTo(stackSize - shrinkDelta);
				stackSize -= shrinkDelta;
			}

			++framesUndone;
			version(debug_observer) writefln("Undo stack %s\n", undoStack.data);
		}
	}
}

struct ObservableRegisters(R, ubyte addressSpaceBytes)
{
	union
	{
		R registers;
		ubyte[R.sizeof] observableArray;
	}

	UndoObserver!addressSpaceBytes observer;

	alias ArrayElement = addressSpaceType!(addressSpaceBytes);

	@disable this();

	this(ubyte a)
	{
		observableArray[] = 0;
		observer = UndoObserver!addressSpaceBytes(observableArray[]);
	}

	// setter
	auto opDispatch(string member)(typeof(__traits(getMember, registers, member)) newValue)
	{
		alias M = typeof(__traits(getMember, registers, member));

		auto value = __traits(getMember, registers, member);

		if (value == newValue) return value;

		version(debug_observer) writefln("before change %s", observableArray);

		observer.addUndoAction(
			__traits(getMember, registers, member).offsetof,
			*(cast(ubyte[M.sizeof]*)&newValue)
		);

		__traits(getMember, registers, member) = newValue;

		version(debug_observer) writefln("after change %s\n", observableArray);

		return __traits(getMember, registers, member);
	}

	// getter
	auto opDispatch(string member)()
	{
		return __traits(getMember, registers, member);//RegisterAccess();
	}

	auto opIndex(size_t index)
	{
		return (cast(ArrayElement[])observableArray)[index];
	}

	void opSliceAssign(ArrayElement[] data, size_t i, size_t j)
	{
		assert(j <= (cast(ArrayElement[])observableArray).length);
		assert(i < j);

		assert(data.length == j - i, format("Arrays have different sizes %s and %s", data.length, j - i));
		//version(debug_observer) writefln("before change %s", observableArray);

		observer.addUndoAction(i * ArrayElement.sizeof, cast(ubyte[])data);

		(cast(ArrayElement[])observableArray)[i..j] = data;
		//version(debug_observer) writefln("after change %s\n", observableArray);
	}

	ArrayElement opIndexAssign(ArrayElement data, size_t index)
	{
		assert(index <= (cast(ArrayElement[])observableArray).length);

		observer.addUndoAction(index * ArrayElement.sizeof, *(cast(ubyte[ArrayElement.sizeof]*)&data));

		return (cast(ArrayElement[])observableArray)[index] = data;
	}
}

struct ObservableMemory(M, ubyte addressSpaceBytes)
{
	union
	{
		M memory;
		ubyte[M.sizeof] observableArray;
	}

	UndoObserver!addressSpaceBytes observer;

	@disable this();

	this(ubyte a)
	{
		observableArray[] = 0;
		observer = UndoObserver!addressSpaceBytes(observableArray[]);
	}

	alias Element = ElementType!M;

	void opSliceAssign(Element[] data, size_t i, size_t j)
	{
		assert(j <= (cast(Element[])observableArray).length);
		assert(i < j);

		assert(data.length == j - i, format("Arrays have different sizes %s and %s", data.length, j - i));
		//version(debug_observer) writefln("before change %s", observableArray);

		observer.addUndoAction(i * Element.sizeof, cast(ubyte[])data);

		(cast(Element[])observableArray)[i..j] = data;
		//version(debug_observer) writefln("after change %s\n", observableArray);
	}

	Element opIndexAssign(Element data, size_t index)
	{
		assert(index <= (cast(Element[])observableArray).length);

		observer.addUndoAction(index * Element.sizeof, *(cast(ubyte[Element.sizeof]*)&data));

		return (cast(Element[])observableArray)[index] = data;
	}

	Element opIndex(size_t index)
	{
		return (cast(Element[])observableArray)[index];
	}
}