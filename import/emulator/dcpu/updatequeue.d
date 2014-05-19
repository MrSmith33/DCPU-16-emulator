/**
Copyright: Copyright (c) 2013-2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.dcpu.updatequeue;

import std.algorithm : swap, filter, sort;
import std.stdio;

import emulator.dcpu.devices.idevice;

struct UpdateQuery(Cpu)
{
	IDevice!Cpu device;
	ulong delay;
	size_t message;
}

struct UpdateQueue(Cpu)
{
	ulong ticksAccumulated;
	bool empty = true;
	UpdateQuery!Cpu*[] queries;

	void onTick(ulong ticksElapsed)
	{
		ticksAccumulated += ticksElapsed;

		if (!empty && ticksAccumulated > queries[0].delay)
		{
			queries_loop:
			foreach(ref query; queries)
			{
				ulong ticks = ticksAccumulated;
				while (ticks >= query.delay)
				{
					ticks -= query.delay;
					query.device.handleUpdateQuery(query.message, query.delay);
					//writefln("delay %s", query.delay);
					if (query.delay == 0) // remove query
					{
						destroy(query);
						continue queries_loop;
					}
				}

				query.delay -= ticks;
			}

			//writefln("queries %s", queries);

			UpdateQuery!Cpu*[] tempQueries = queries;
			queries.length = 0;

			foreach(ref query; tempQueries.filter!((a) => a !is null))
			{
				queries.assumeSafeAppend() ~= query;
			}

			//writefln("queries %s", queries);

			ticksAccumulated = 0;

			if (queries.length == 0)
			{
				empty = true;
				return;
			}

			//writefln("queries %s", queries);

			sort!("a.delay < b.delay")(queries);

			//writefln("queries %s", queries);
		}

		//writefln("on tick %s", queries);
	}

	/// Adds update query
	void addQuery(IDevice!Cpu device, ulong delay, size_t message = 0)
	{
		//writefln("begin add %s, %s", device, queries);
		ulong realDelay = delay + ticksAccumulated;

		queries ~= new UpdateQuery!Cpu(device, realDelay, message);

		foreach(i, query; queries)
		{
			if ((*query).delay > realDelay) // found place
			{
				foreach_reverse(j; i+1..queries.length)
				{
					swap(queries[j], queries[j-1]);
				}

				break;
			}
		}
		
		empty = false;

		//writefln("end add %s", queries);
	}

	/// Removes all occurences of device in queries in place.
	void removeQueries(IDevice!Cpu device)
	{
		//writefln("begin remove %s, %s", device, queries);
		UpdateQuery!Cpu*[] tempQueries = queries;
		queries.length = 0;

		foreach(ref query; tempQueries.filter!((a) => (*a).device != device))
		{
			queries.assumeSafeAppend() ~= query;
		}

		if (queries.length == 0) empty = true;

		//writefln("end remove %s", queries);
	}
}