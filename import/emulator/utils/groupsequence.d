/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module emulator.utils.groupsequence;

import std.range : isInputRange, isInfinite, isForwardRange, ElementType;
import std.array : empty, front, popFront, save;
import std.functional : binaryFun;
import std.typecons : tuple, Tuple;

// group
/**
Similarly to $(D uniq), $(D group) iterates consecutive
elements of the given range. The element type is $(D
Tuple!(ElementType!R, uint)) because it includes the count of
grouped elements seen. Elements are grouped by assessing using
the predicate $(D pred), by default $(D "a == b"). The predicate
is called for pairs of neighboring elements.

$(D Group) is an input range if $(D R) is an input range, and a
forward range in all other cases.
*/
struct GroupSequence(alias pred, R) if (isInputRange!R)
{
    private R _input;
    private Tuple!(ElementType!R, uint) _current;
    private alias binaryFun!pred comp;

    this(R input)
    {
        _input = input;
        if (!_input.empty) popFront();
    }

    void popFront()
    {
        if (_input.empty)
        {
            _current[1] = 0;
        }
        else
        {
            _current = tuple(_input.front, 1u);
            auto lastInGroup = _current[0];
            _input.popFront();
            
            while (!_input.empty && comp(lastInGroup, _input.front))
            {
                ++_current[1];
                lastInGroup = _input.front;
                _input.popFront();
            }
        }
    }

    static if (isInfinite!R)
    {
        enum bool empty = false;  // Propagate infiniteness.
    }
    else
    {
        @property bool empty()
        {
            return _current[1] == 0;
        }
    }

     @property ref Tuple!(ElementType!R, uint) front()
    {
        assert(!empty);
        return _current;
    }

    static if (isForwardRange!R) {
        @property typeof(this) save() {
            typeof(this) ret = this;
            ret._input = this._input.save;
            ret._current = this._current;
            return ret;
        }
    }
}

/// Ditto
GroupSequence!(pred, Range) groupSequence(alias pred = "a == b", Range)(Range r)
{
    return typeof(return)(r);
}

unittest
{
    import std.algorithm : equal;
    
    // group continuos
    int[] numbers = [1, 2, 3,  5, 6, 7,  10];
    assert(equal(groupSequence!"b-a==1"(numbers), [tuple(1, 3u), tuple(5, 3u), tuple(10, 1u)][]));
    
    // Plain group with pred "a==b"
    int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
    assert(equal(groupSequence(arr), [ tuple(1, 1u), tuple(2, 4u), tuple(3, 1u),
        tuple(4, 3u), tuple(5, 1u) ][]));
}