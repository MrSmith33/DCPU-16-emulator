module dcpu.interruptqueue;

@safe nothrow:

struct InterruptQueue
{
	ushort[256] buffer;
	ubyte firstPos;
	ubyte lastPos;
	ubyte size;

	@property ushort first()
	{
		return buffer[firstPos];
	}

	@property ushort last()
	{
		return buffer[lastPos];
	}

	@property bool isFull()
	{
		return size >= 256;
	}

	void add(ushort element)
	{
		buffer[++lastPos] = element;
		++size;
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	ushort take()
	in
	{
		assert(size > 0);
	}
	body
	{
		--size;
		return buffer[firstPos++];
	}

	void clear() nothrow
	{
		firstPos = 0;
		lastPos = 0;
		size = 0;
	}
}