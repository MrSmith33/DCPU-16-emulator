/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.utils.ringbuffer;

@safe nothrow:

class RingBufferFullException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

enum OnBufferFull
{
	overwrite,
	throwException
}

struct RingBuffer(E, size_t bufSize, OnBufferFull onBufferFull = OnBufferFull.overwrite)
{
	E[bufSize] buffer;
	size_t frontPos;
	size_t backPos;
	size_t length;

	@property E front()
	{
		return buffer[frontPos];
	}

	@property E back()
	{
		return buffer[backPos];
	}

	@property bool isFull()
	{
		return length >= bufSize;
	}

	@property bool empty()
	{
		return length == 0;
	}

	void pushBack(E element)
	{
		if (isFull)
		{
			static if (onBufferFull == OnBufferFull.overwrite)
			{
				backPos = (backPos + 1) % bufSize;
				frontPos = (frontPos + 1) % frontPos;

				buffer[backPos] = element;

				return;
			}
			else
			{
				throw new RingBufferFullException("Ring buffer is full");
			}
		}

		buffer[backPos] = element;
		backPos = (backPos + 1) % bufSize;
		++length;
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	E popBack()
	in
	{
		assert(length > 0);
	}
	body
	{
		--length;
		auto temp = backPos;
		backPos = (backPos - 1) % bufSize;
		return buffer[temp];
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	E popFront()
	in
	{
		assert(length > 0);
	}
	body
	{
		--length;
		auto temp = frontPos;
		frontPos = (frontPos + 1) % bufSize;
		return buffer[temp];
	}

	void pushFront(E element)
	{
		frontPos = (frontPos - 1) % bufSize;
		buffer[frontPos] = element;
		++length;
	}

	void clear() nothrow
	{
		frontPos = 0;
		backPos = 0;
		length = 0;
	}
}