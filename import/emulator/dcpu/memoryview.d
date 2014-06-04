/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.dcpu.memoryview;

import std.string;
import std.array;
import std.format;
import std.stdio;
import std.math : ceil;

public import anchovy.gui.databinding.list;

import emulator.dcpu.dcpu;

class MemoryView(Cpu) : List!dstring
{
	Cpu* dcpu;
	ushort itemsPerLine = 8;
	bool collapseZeros = false;
	Appender!(ushort[]) nonZeroLines;

	this(Cpu* dcpu)
	{
		this.dcpu = dcpu;
	}

	private ushort valueAt(size_t index)
	{
		if (index >= 0x10000)
			return 0;
		else
			return dcpu.mem[index];
	}

	void update()
	{
		if (!collapseZeros) return;

		size_t pointer;
		nonZeroLines.shrinkTo(0);

		while (pointer < 0x10000)
		{
			bool allZeros = true;
			foreach(i; 0..itemsPerLine)
			{
				if (valueAt(pointer + i) != 0)
				{
					allZeros = false;
					break;
				}
			}

			if (!allZeros)
			{
				nonZeroLines ~= cast(ushort)pointer;
			}

			pointer += itemsPerLine;
		}
	}

	override dstring opIndex(size_t index)
	{
		auto writer = appender!dstring();
		ushort address;

		if (collapseZeros)
		{
			if (index >= nonZeroLines.data.length) return "";

			address = nonZeroLines.data[index];
		}
		else
		{
			address = cast(ushort)(index * itemsPerLine);
		}

		formattedWrite(writer, "%04x: ", address);

		foreach(i; 0..itemsPerLine)
		{
			size_t itemIndex = address + i;
			
			if (itemIndex < 0x10000)
				formattedWrite(writer, "%04X ", dcpu.mem[itemIndex]);
		}
		
		return writer.data;
	}

	override dstring opIndexAssign(dstring data, size_t index)
	{
		return "";
	}

	override size_t length() @property
	{
		if (collapseZeros)
			return nonZeroLines.data.length;
		else
			return cast(size_t)ceil(cast(float)0x10000 / itemsPerLine);
	}

	override size_t push(dstring item)
	{
		return 0;
	}

	override dstring remove(size_t index)
	{
		return "";
	}
}