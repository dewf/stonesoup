module set_tests;

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

@("dup and rvalue assignment")
unittest {
    auto source = Set!int(1, 2, 3);
    const constSource = Set!int(4, 5, 6);

    auto copy = source.dup();
    assert(sorted!int(copy.array()) == [1, 2, 3]);

    // Mutating copy must not affect source
    copy.set(99);
    assert(!source.contains(99));

    // Assigning rvalues (including .dup() from mutable and const sets)
    Set!int target;
    target = source.dup();
    assert(sorted!int(target.array()) == [1, 2, 3]);

    target = constSource.dup();
    assert(sorted!int(target.array()) == [4, 5, 6]);
    target.set(100);
    assert(!constSource.contains(100));

    target = Set!int(7, 8);
    assert(sorted!int(target.array()) == [7, 8]);

    target = Set!int.empty;
    assert(target.isEmpty());

    // Chained assignment
    Set!int a, b;
    a = b = constSource.dup();
    assert(sorted!int(a.array()) == [4, 5, 6]);
    assert(sorted!int(b.array()) == [4, 5, 6]);
    b.set(42);
    assert(!a.contains(42));
}

@("const and immutable copy and assignment")
unittest {
    const cset = Set!int(10, 20, 30);
    immutable iset = Set!int(40, 50);

    // Copy initialization from const and immutable
    Set!int fromConst = cset;
    assert(sorted!int(fromConst.array()) == [10, 20, 30]);
    fromConst.set(99);
    assert(!cset.contains(99));

    Set!int fromImmutable = iset;
    assert(sorted!int(fromImmutable.array()) == [40, 50]);

    // Assignment from const lvalue, immutable lvalue, and const rvalue
    Set!int target;
    target = cset;
    assert(sorted!int(target.array()) == [10, 20, 30]);

    target = iset;
    assert(sorted!int(target.array()) == [40, 50]);

    const(Set!int) makeConst() => Set!int(70, 80);
    target = makeConst();
    assert(sorted!int(target.array()) == [70, 80]);
}

@("union and intersect with rvalues")
unittest {
    auto left = Set!int(1, 2, 3);
    auto right = Set!int(3, 4, 5);

    auto u1 = left.union_(Set!int(4, 5));
    assert(sorted!int(u1.array()) == [1, 2, 3, 4, 5]);

    auto u2 = left.union_(right.dup());
    assert(sorted!int(u2.array()) == [1, 2, 3, 4, 5]);

    auto i1 = left.intersect(Set!int(2, 3, 9));
    assert(sorted!int(i1.array()) == [2, 3]);

    auto chained = Set!int(10).union_(left.intersect(right));
    assert(sorted!int(chained.array()) == [3, 10]);

    // Assign results directly into an existing Set
    Set!int target;
    target = left.union_(right);
    assert(sorted!int(target.array()) == [1, 2, 3, 4, 5]);

    target = left.intersect(right);
    assert(sorted!int(target.array()) == [3]);
}
