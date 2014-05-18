/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module dcpu.ringbuffer;

@safe nothrow:

struct RingBuffer(E, size_t bufSize)
{
	E[bufSize] buffer;
	size_t frontPos;
	size_t backPos;
	size_t size;

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
		return size >= bufSize;
	}

	@property bool empty()
	{
		return size == 0;
	}

	void pushBack(E element)
	{
		backPos = (backPos + 1) % bufSize;
		buffer[backPos] = element;
		++size;
	}

	/// Dequeue item from queue.
	///
	/// Size must be checked
	E popBack()
	in
	{
		assert(size > 0);
	}
	body
	{
		--size;
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
		assert(size > 0);
	}
	body
	{
		--size;
		auto temp = frontPos;
		frontPos = (frontPos + 1) % bufSize;
		return buffer[temp];
	}

	void pushFront(E element)
	{
		frontPos = (frontPos - 1) % bufSize;
		buffer[frontPos] = element;
		++size;
	}

	void clear() nothrow
	{
		frontPos = 0;
		backPos = 0;
		size = 0;
	}
}