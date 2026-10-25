module tests;

import stonesoup.set : Set;

T[] sorted(T, R)(R range) {
    import std.algorithm.sorting : sort;
    import std.range : array;
    return range.dup.sort.array;
}

@("varargs ctor")
unittest {
    auto x = Set!int(99, 100, 101);
    assert(sorted!int(x.array()) == [99, 100, 101]);
}

@("simple test")
unittest {
    Set!int x;
    x.set(123);
    x.set(456);
    assert(sorted!int(x.array()) == [123, 456]);
}

@("contains")
unittest {
    Set!int x;
    x.set(123);
    x.set(456);
    assert(x.contains(456));
    assert(x.contains(123));
    assert(!x.contains(99));
}

@("range ctor, length")
unittest {
    import std.algorithm: map;
    auto r = [1, 2, 3, 4, 5, 6].map!(x => x * 3);
    auto x = Set!int(r);
    assert(sorted!int(x.array()) == [3, 6, 9, 12, 15, 18]);
    assert(x.length == 6);
}

@("empty check")
unittest {
    auto x = Set!int.empty;
    assert(x.length == 0);
}

@("~ operator overload")
unittest {
    auto x = Set!int.empty;
    x ~= 123;
    assert(x.contains(123));
}

@("assignment")
unittest {
    auto x = Set!int(1, 2, 3);
    auto y = Set!int(5, 6, 7);
    x = y;
    assert(sorted!int(x.array()) == [5, 6, 7]);
}

@("clear")
unittest {
    auto x = Set!int(1, 2, 3, 4, 5);
    x.clear();
    assert(x.length == 0);
    assert(!x.contains(1));
}

@("multi-set, remove")
unittest {
    auto x = Set!int(1, 2, 3);
    x.set(1001, 1002, 1003);
    assert(sorted!int(x.array()) == [1, 2, 3, 1001, 1002, 1003]);
    x.remove(1002);
    x.remove(1003);
    assert(sorted!int(x.array()) == [1, 2, 3, 1001]);
}

@("remove overload")
unittest {
    auto x = Set!int(1, 2, 3, 4, 5);
    x -= 2;
    x -= 3;
    x -= 4;
    assert(sorted!int(x.array()) == [1, 5]);
}

@("foreach")
unittest {
    auto set = Set!int(99, 100, 101, 102, 103);
    int[] found;
    foreach (item; set) {
        found ~= item;
    }
    assert(sorted!int(found) == [99, 100, 101, 102, 103]);
}

@("bitwise operator overloads")
unittest {
    auto set = Set!int(1);
    set |= 2;
    set |= 100;
    assert(sorted!int(set.array()) == [1, 2, 100]);
    set &= 100;
    assert(set.array() == [ 100 ]);
    set &= 3;
    assert(set.isEmpty());
}

@("union")
unittest {
    auto left = Set!int(1, 2, 3);
    auto right = Set!int(99, 100, 101);
    auto result = left.union_(right);
    assert(sorted!int(result.array()) == [1, 2, 3, 99, 100, 101]);
}

@("intersect")
unittest {
    auto left = Set!int(1, 2, 3, 4, 5);
    auto right = Set!int(3, 4, 5, 6, 7);
    auto result = left.intersect(right);
    assert(sorted!int(result.array()) == [3, 4, 5]);
}
