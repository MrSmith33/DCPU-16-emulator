/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.ringbuffer;

@safe nothrow:

class RingBufferFull : Exception
{
}

enum OnBufferFull
{
	overwrite,
	ignore,
	throwException
}

struct RingBuffer(E, size_t bufSize)
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
		backPos = (backPos + 1) % bufSize;
		buffer[backPos] = element;
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