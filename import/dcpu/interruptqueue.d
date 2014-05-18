/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.interruptqueue;

@safe nothrow:

struct InterruptQueue
{
	ushort[256] buffer;
	ubyte firstPos;
	ubyte lastPos;
	ubyte size;

	@property ushort front()
	{
		return buffer[firstPos];
	}

	@property ushort back()
	{
		return buffer[lastPos];
	}

	@property bool isFull()
	{
		return size >= 256;
	}

	@property bool empty()
	{
		return size == 0;
	}

	void pushBack(ushort element)
	{
		buffer[++lastPos] = element;
		++size;
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	ushort popBack()
	in
	{
		assert(size > 0);
	}
	body
	{
		--size;
		return buffer[lastPos--];
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	ushort popFront()
	in
	{
		assert(size > 0);
	}
	body
	{
		--size;
		return buffer[firstPos++];
	}

	void pushFront(ushort element)
	{
		buffer[--firstPos] = element;
		++size;
	}

	void clear() nothrow
	{
		firstPos = 0;
		lastPos = 0;
		size = 0;
	}
}