/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module memoryview;

import std.string;
import std.array;
import std.format;
import std.stdio;
import std.math : ceil;

public import anchovy.gui.databinding.list;

import dcpu.dcpu;

class MemoryView : List!dstring
{
	Dcpu* dcpu;
	ushort itemsPerLine = 8;

	this(Dcpu* dcpu)
	{
		this.dcpu = dcpu;
	}

	override dstring opIndex(size_t index)
	{
		auto writer = appender!dstring();
		formattedWrite(writer, "%04x: ", index * itemsPerLine);

		foreach(i; 0..itemsPerLine)
		{
			size_t itemIndex = index * itemsPerLine + i;
			
			if (itemIndex >= 0x10000)
				formattedWrite(writer, "%04X ", 0);
			else
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