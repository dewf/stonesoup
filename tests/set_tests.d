module set_tests;

import stonesoup.set;

import std.algorithm.iteration : filter, fold, map;
import std.algorithm.searching : any, canFind;
import std.algorithm.sorting : sort;
import std.array : array;
import std.conv : to;
import std.format : format;
import std.range : iota, isForwardRange, isInputRange, repeat;

private {
    T[] sorted(T)(T[] arr) {
        auto copy = arr.dup;
        copy.sort();
        return copy;
    }

    struct Point {
        int x;
        int y;
    }

    struct NoDefault {
        int id;
        @disable this();
        this(int id) pure nothrow @safe @nogc {
            this.id = id;
        }
    }

    struct ConstMember {
        const int id;
    }

    class Widget {
        int id;
        this(int id) {
            this.id = id;
        }
        override bool opEquals(Object o) {
            if (auto w = cast(Widget) o) {
                return id == w.id;
            }
            return false;
        }
        override size_t toHash() @trusted nothrow {
            return id;
        }
        override string toString() const {
            return format("Widget(%d)", id);
        }
    }

    enum Color { red, green, blue }
}

@("default init, empty, length, and opCast!bool")
unittest {
    Set!int s;
    assert(s.empty);
    assert(s.length == 0);
    assert(!s);
    assert(!cast(bool) s);

    auto s2 = Set!int();
    assert(s2.empty);
    assert(s2 == s);

    auto s3 = set!int();
    assert(s3.empty);
    assert(s3 == s);

    s.add(10);
    assert(!s.empty);
    assert(s.length == 1);
    assert(cast(bool) s);
    if (!s) assert(false);

    s.remove(10);
    assert(s.empty);
    assert(s.length == 0);
    assert(!s); // Unlike raw AA, truthiness reflects emptiness even after remove
}

@("template constraint rejects void")
unittest {
    static assert(!__traits(compiles, Set!void));
    static assert(!__traits(compiles, set!void()));
}

@("variadic, slice, range, and factory construction")
unittest {
    // Variadic elements (deduplicated)
    auto a = Set!int(3, 1, 2, 1, 3);
    assert(a.length == 3);
    assert(sorted(a.array) == [1, 2, 3]);

    // Single element
    auto single = Set!int(42);
    assert(single.length == 1);
    assert(42 in single);

    // Dynamic array, const array, immutable array, static array slice
    auto fromDyn = Set!int([10, 20, 10, 30]);
    assert(sorted(fromDyn.array) == [10, 20, 30]);

    const(int)[] carr = [4, 5, 6];
    auto fromConstArr = Set!int(carr);
    assert(sorted(fromConstArr.array) == [4, 5, 6]);

    immutable(int)[] iarr = [7, 8, 9];
    auto fromImmArr = Set!int(iarr);
    assert(sorted(fromImmArr.array) == [7, 8, 9]);

    int[3] sarr = [1, 2, 3];
    auto fromStatic = Set!int(sarr[]);
    assert(sorted(fromStatic.array) == [1, 2, 3]);

    // Lazy input range
    auto fromRange = Set!int(iota(1, 6).map!(x => x * 2));
    assert(sorted(fromRange.array) == [2, 4, 6, 8, 10]);

    // Implicit element widening in range constructor
    short[] shorts = [1, 2, 3];
    auto widened = Set!long(shorts);
    assert(sorted(widened.array) == [1L, 2L, 3L]);

    // Infinite ranges are rejected at compile time
    static assert(!__traits(compiles, Set!int(repeat(1))));
    static assert(!__traits(compiles, repeat(1).toSet));

    // Convenience factory functions: set(...) and toSet
    auto f1 = set(1, 2, 3, 2);
    static assert(is(typeof(f1) == Set!int));
    assert(f1 == Set!int(1, 2, 3));

    auto f2 = set(1, 2L, 3);
    static assert(is(typeof(f2) == Set!long));
    assert(f2 == Set!long(1, 2, 3));

    auto f3 = set("alpha", "beta");
    static assert(is(typeof(f3) == Set!string));
    assert("alpha" in f3 && "beta" in f3);

    auto f4 = [5, 6, 5, 7].toSet;
    static assert(is(typeof(f4) == Set!int));
    assert(f4 == set(5, 6, 7));

    auto f5 = iota(1, 4).toSet!long;
    static assert(is(typeof(f5) == Set!long));
    assert(f5 == set(1L, 2L, 3L));

    // Set!string vs single string vs string[] (no ambiguity)
    auto oneStr = Set!string("hello");
    assert(oneStr.length == 1);
    assert("hello" in oneStr);

    auto manyStr = Set!string(["hello", "world"]);
    assert(manyStr.length == 2);
    assert("hello" in manyStr && "world" in manyStr);

    // Set!(immutable(int)[]) with single slice vs slice of slices (no ambiguity)
    // (Mutable int[] is rejected by D AAs as a key type, just like Unit[int[]])
    static assert(!__traits(compiles, Set!(int[])([1, 2])));

    immutable(int)[] slice1 = [1, 2];
    immutable(int)[] slice2 = [3, 4];
    auto oneSlice = Set!(immutable(int)[])(slice1);
    assert(oneSlice.length == 1);
    assert(slice1 in oneSlice);

    auto manySlices = Set!(immutable(int)[])([slice1, slice2]);
    assert(manySlices.length == 2);
    assert(slice1 in manySlices && slice2 in manySlices);
}

@("membership: contains, in, !in, and heterogeneous lookup")
unittest {
    auto s = set("foo", "bar", "baz");
    assert(s.contains("foo"));
    assert(!s.contains("qux"));
    assert("bar" in s);
    assert("qux" !in s);

    // Heterogeneous lookup: mutable char[] against Set!string (zero-copy!)
    char[] buf = "foo".dup;
    assert(s.contains(buf));
    assert(buf in s);
    buf[0] = 'z';
    assert(!s.contains(buf));
    assert(buf !in s);

    // Lookup with const(char)[] slice against Set!string
    const(char)[] cbuf = "bar";
    assert(cbuf in s);
    assert(s.contains(cbuf));
}

@("mutation: add, addAll, remove, removeAll, toggle, retain, clear, rehash")
unittest {
    Set!int s;

    // add returns true only when newly inserted
    assert(s.add(1));
    assert(!s.add(1));
    assert(s.add(2));
    assert(s.length == 2);

    // addAll variadic, range, and Set
    assert(s.addAll(2, 3, 4) == 2);
    assert(s == set(1, 2, 3, 4));
    assert(s.addAll([4, 5, 6]) == 2);
    assert(s == set(1, 2, 3, 4, 5, 6));
    assert(s.addAll(set(5, 6, 7)) == 1);
    assert(s == set(1, 2, 3, 4, 5, 6, 7));

    // remove returns true only when present
    assert(s.remove(7));
    assert(!s.remove(7));
    assert(s.length == 6);

    // removeAll variadic, range, and Set
    assert(s.removeAll(1, 99, 2) == 2);
    assert(s == set(3, 4, 5, 6));
    assert(s.removeAll([3, 100]) == 1);
    assert(s == set(4, 5, 6));
    assert(s.removeAll(set(5, 200)) == 1);
    assert(s == set(4, 6));

    // toggle flips membership and returns new state
    assert(s.toggle(5) == true);
    assert(5 in s);
    assert(s.toggle(5) == false);
    assert(5 !in s);

    // retain and removeIf safely filter in place
    s.addAll(1, 2, 3, 7, 8, 9);
    assert(s.retain!(x => x % 2 == 0)() == 4); // removes 1, 3, 7, 9
    assert(s == set(2, 4, 6, 8));
    assert(s.removeIf!(x => x > 5) == 2); // removes 6, 8
    assert(s == set(2, 4));
    auto s2 = set(1, 2, 3, 4, 5, 6);
    assert(s2.retain!"a % 2 == 0" == 3);
    assert(s2 == set(2, 4, 6));
    assert(s2.retain!(x => x > 100) == 3);
    assert(s2.empty);
    assert(s2.retain!(x => true) == 0);
    assert(s2.removeIf!(x => true) == 0);

    // rehash and clear
    s.rehash();
    assert(!s.empty);
    s.clear();
    assert(s.empty);
    assert(s.length == 0);
}

@("reference semantics, aliasing, dup, and idup")
unittest {
    auto a = set(1, 2, 3);
    auto b = a; // O(1) reference copy, shares backing table
    b.add(4);
    assert(4 in a);
    assert(a == b);

    // dup creates an independent mutable copy
    auto c = a.dup;
    assert(c == a);
    c.add(99);
    assert(99 !in a);
    assert(99 in c);

    // const and immutable copies via dup / idup
    const cs = a;
    auto fromConst = cs.dup;
    static assert(is(typeof(fromConst) == Set!int));
    fromConst.add(100);
    assert(100 !in cs);

    immutable iset = a.idup;
    static assert(is(typeof(iset) == immutable(Set!int)));
    assert(iset == a);
    a.add(200);
    assert(200 !in iset);

    auto fromImm = iset.dup;
    static assert(is(typeof(fromImm) == Set!int));
    assert(fromImm == set(1, 2, 3, 4));

    // Self-aliasing in-place operations must be completely safe (no UB)
    auto alias1 = set(1, 2, 3);
    auto alias2 = alias1;
    assert(alias1.addAll(alias2) == 0);
    assert(alias1 == set(1, 2, 3));

    assert(alias1.intersectWith(alias2) == 0);
    assert(alias1 == set(1, 2, 3));

    alias1 |= alias2;
    assert(alias1 == set(1, 2, 3));

    alias1 &= alias2;
    assert(alias1 == set(1, 2, 3));

    assert(alias1.removeAll(alias2) == 3);
    assert(alias1.empty && alias2.empty);

    auto alias3 = set(10, 20);
    auto alias4 = alias3;
    alias3 ^= alias4;
    assert(alias3.empty && alias4.empty);

    auto alias5 = set(10, 20);
    auto alias6 = alias5;
    alias5 -= alias6;
    assert(alias5.empty && alias6.empty);
}

@("iteration: foreach, opSlice, byElement, ForwardRange, and std.algorithm interop")
unittest {
    auto s = set(10, 20, 30, 40);

    // opSlice and byElement return a ForwardRange
    auto r = s[];
    static assert(isInputRange!(typeof(r)));
    static assert(isForwardRange!(typeof(r)));
    auto saved = r.save;
    assert(sorted(r.array) == [10, 20, 30, 40]);
    assert(sorted(saved.array) == [10, 20, 30, 40]);
    assert(sorted(s.byElement.array) == [10, 20, 30, 40]);

    // foreach on mutable, const, and immutable sets
    int sumMut = 0;
    foreach (x; s) sumMut += x;
    assert(sumMut == 100);

    const cs = s;
    int sumConst = 0;
    foreach (x; cs) sumConst += x;
    assert(sumConst == 100);

    immutable iset = s.idup;
    int sumImm = 0;
    foreach (x; iset) sumImm += x;
    assert(sumImm == 100);

    // Direct std.algorithm pipeline via set[]
    auto doubled = s[].filter!(x => x >= 20).map!(x => x * 2).toSet;
    assert(doubled == set(40, 60, 80));
    assert(s[].fold!((acc, x) => acc + x)(0) == 100);
    assert(s[].any!(x => x == 30));
    assert(s[].canFind(20));
}

@("set-theoretic predicates: subset, proper subset, superset, disjoint")
unittest {
    auto emptySet = set!int();
    auto a = set(1, 2);
    auto b = set(1, 2, 3);
    auto c = set(4, 5);

    // Subset / proper subset
    assert(emptySet.isSubsetOf(emptySet));
    assert(!emptySet.isProperSubsetOf(emptySet));
    assert(emptySet.isSubsetOf(a));
    assert(emptySet.isProperSubsetOf(a));

    assert(a.isSubsetOf(a));
    assert(!a.isProperSubsetOf(a));
    assert(a.isSubsetOf(b));
    assert(a.isProperSubsetOf(b));
    assert(!b.isSubsetOf(a));
    assert(!a.isSubsetOf(c));

    // Superset / proper superset
    assert(b.isSupersetOf(a));
    assert(b.isProperSupersetOf(a));
    assert(a.isSupersetOf(a));
    assert(!a.isProperSupersetOf(a));
    assert(a.isSupersetOf(emptySet));
    assert(a.isProperSupersetOf(emptySet));
    assert(!a.isSupersetOf(b));

    // Disjoint
    assert(emptySet.isDisjointWith(emptySet));
    assert(emptySet.isDisjointWith(a));
    assert(a.isDisjointWith(emptySet));
    assert(a.isDisjointWith(c));
    assert(c.isDisjointWith(a));
    assert(!a.isDisjointWith(b));
    assert(!a.isDisjointWith(a));

    // Works with const / immutable combinations
    const cb = b;
    immutable ic = c.idup;
    assert(a.isSubsetOf(cb));
    assert(cb.isSupersetOf(a));
    assert(a.isDisjointWith(ic));
}

@("non-mutating set algebra: setUnion, intersection, difference, symmetricDifference")
unittest {
    auto a = set(1, 2, 3, 4);
    auto b = set(3, 4, 5, 6);
    auto e = set!int();

    assert(a.setUnion(b) == set(1, 2, 3, 4, 5, 6));
    assert(a.intersection(b) == set(3, 4));
    assert(a.difference(b) == set(1, 2));
    assert(b.difference(a) == set(5, 6));
    assert(a.symmetricDifference(b) == set(1, 2, 5, 6));

    // Identity / empty / self cases
    assert(a.setUnion(a) == a);
    assert(a.intersection(a) == a);
    assert(a.difference(a).empty);
    assert(a.symmetricDifference(a).empty);

    assert(a.setUnion(e) == a);
    assert(e.setUnion(a) == a);
    assert(a.intersection(e).empty);
    assert(e.intersection(a).empty);
    assert(a.difference(e) == a);
    assert(e.difference(a).empty);
    assert(a.symmetricDifference(e) == a);
    assert(e.symmetricDifference(a) == a);

    // Originals remain untouched
    assert(a == set(1, 2, 3, 4));
    assert(b == set(3, 4, 5, 6));

    // Works with const and immutable operands
    const ca = a;
    immutable ib = b.idup;
    assert(ca.setUnion(ib) == set(1, 2, 3, 4, 5, 6));
    assert(ca.intersection(ib) == set(3, 4));
    assert(ca.difference(ib) == set(1, 2));
    assert(ca.symmetricDifference(ib) == set(1, 2, 5, 6));
}

@("operator overloads: set-set and set-element binary and compound assignment")
unittest {
    const a = set(1, 2, 3);
    const b = set(3, 4, 5);

    // Binary set-set
    assert((a | b) == set(1, 2, 3, 4, 5));
    assert((a & b) == set(3));
    assert((a - b) == set(1, 2));
    assert((a ^ b) == set(1, 2, 4, 5));

    // Binary set-element (consistent with singleton {elem})
    assert((a | 4) == set(1, 2, 3, 4));
    assert((a | 2) == set(1, 2, 3));
    assert((a - 2) == set(1, 3));
    assert((a - 99) == set(1, 2, 3));
    assert((a ^ 2) == set(1, 3));
    assert((a ^ 4) == set(1, 2, 3, 4));
    assert((a & 2) == set(2));
    assert((a & 99).empty);

    // Binary string element removal
    const strSet = set("one", "two");
    assert((strSet - "one") == set("two"));

    // Compound assignment: set-element
    auto m = set(1);
    m ~= 2;
    m |= 3;
    assert(m == set(1, 2, 3));

    m -= 2;
    assert(m == set(1, 3));

    m ^= 3; // removes 3
    m ^= 4; // adds 4
    assert(m == set(1, 4));

    m &= 4; // keeps only 4
    assert(m == set(4));

    m &= 999; // 999 not present -> empties set
    assert(m.empty);

    // Compound assignment: set-range
    m ~= [10, 20, 30];
    assert(m == set(10, 20, 30));
    m ~= iota(30, 33);
    assert(m == set(10, 20, 30, 31, 32));

    // Compound assignment: set-set
    auto x = set(1, 2, 3);
    x |= set(3, 4);
    assert(x == set(1, 2, 3, 4));
    x ~= set(4, 5);
    assert(x == set(1, 2, 3, 4, 5));
    x -= set(1, 5);
    assert(x == set(2, 3, 4));
    x &= set(3, 4, 9);
    assert(x == set(3, 4));
    x ^= set(4, 5, 6);
    assert(x == set(3, 5, 6));

    // Chaining compound assignments returns ref this
    auto chain = set!int();
    ((chain ~= 1) |= 2) ~= 3;
    assert(chain == set(1, 2, 3));

    // Incompatible set types are rejected
    static assert(!__traits(compiles, a | set("x")));
    static assert(!__traits(compiles, a | set(1L)));
    // Partial-order opCmp is intentionally NOT defined
    static assert(!__traits(compiles, a < b));
    static assert(!__traits(compiles, a <= b));
}

@("higher-order UFCS methods: exists, forall, countIf, filterSet, filterNot, mapSet, partitionSet")
unittest {
    const s = set(1, 2, 3, 4, 5, 6);
    const emptySet = set!int();

    // exists / forall / countIf with lambdas and string predicates
    assert(s.exists!(x => x > 5));
    assert(!s.exists!(x => x > 10));
    assert(!emptySet.exists!(x => true));

    assert(s.forall!(x => x > 0));
    assert(!s.forall!"a % 2 == 0");
    assert(emptySet.forall!(x => false)); // Vacuous truth

    assert(s.countIf!(x => x % 2 == 0) == 3);
    assert(s.countIf!"a > 4" == 2);
    assert(emptySet.countIf!(x => true) == 0);

    // filterSet & filterNot
    auto evens = s.filterSet!(x => x % 2 == 0);
    assert(evens == set(2, 4, 6));
    assert(s.filterSet!"a > 100".empty);

    auto odds = s.filterNot!(x => x % 2 == 0);
    assert(odds == set(1, 3, 5));

    // mapSet (including many-to-one collapse and type change)
    auto mods = s.mapSet!(x => x % 3);
    assert(mods == set(0, 1, 2));

    auto asStrings = set(1, 2).mapSet!(x => x.to!string);
    static assert(is(typeof(asStrings) == Set!string));
    assert(asStrings == set("1", "2"));

    // partitionSet (single pass)
    auto parts = s.partitionSet!(x => x % 2 == 0);
    assert(parts.matching == set(2, 4, 6));
    assert(parts.rest == set(1, 3, 5));
}

@("equality, order-independent toHash, AA keys, and nested Set!(Set!T)")
unittest {
    // Different insertion orders and deletions yield equal sets and identical hashes
    Set!int a, b;
    foreach (i; 0 .. 100) a.add(i);
    foreach_reverse (i; 0 .. 100) b.add(i);
    foreach (i; 100 .. 200) a.add(i);
    foreach (i; 100 .. 200) a.remove(i);

    assert(a == b);
    assert(a.toHash() == b.toHash());
    assert(hashOf(a) == hashOf(b));

    // Usable as an AA key
    string[Set!int] labels;
    labels[set(1, 2)] = "pair";
    labels[set(3)] = "single";
    assert(labels[set(2, 1)] == "pair");
    assert(labels[set(3)] == "single");
    assert(labels.length == 2);

    // Nested Set!(Set!int) — including operators distinguishing Set!int elem vs Set!(Set!int) set
    Set!(Set!int) powerSet;
    powerSet.add(set!int());
    powerSet.add(set(1));
    powerSet.add(set(2));
    powerSet.add(set(1, 2));
    assert(powerSet.length == 4);
    assert(set(2, 1) in powerSet);
    assert(set(3) !in powerSet);

    auto extra = powerSet | set(3); // Set-Element union!
    assert(extra.length == 5);
    assert(set(3) in extra);

    auto combined = powerSet | Set!(Set!int)(set(3), set(4)); // Set-Set union!
    assert(combined.length == 6);
    assert(set(3) in combined && set(4) in combined);

    powerSet ~= set(99);
    assert(set(99) in powerSet);
    powerSet -= set(99);
    assert(set(99) !in powerSet);
}

@("toString formatting with std.format and std.conv.to")
unittest {
    assert(set!int().to!string == "Set()");
    assert(set(42).to!string == "Set(42)");
    assert(format("%s", set("hello")) == `Set("hello")`);

    auto pair = format("%s", set(1, 2));
    assert(pair == "Set(1, 2)" || pair == "Set(2, 1)");
}

@("attribute inference: @safe, pure, nothrow, and @nogc")
unittest {
    // Non-allocating operations must be pure nothrow @safe @nogc
    static void checkNoGC(const Set!int a, const Set!int b) pure nothrow @safe @nogc {
        assert(a.length == 3);
        assert(!a.empty);
        assert(cast(bool) a);
        assert(1 in a);
        assert(99 !in a);
        assert(a.contains(2));
        assert(a == a);
        assert(a != b);
        const h = a.toHash();
        assert(h == hashOf(a));
        assert(a.isSubsetOf(a));
        assert(!a.isProperSubsetOf(a));
        assert(a.isSupersetOf(a));
        assert(!a.isProperSupersetOf(a));
        assert(!a.isDisjointWith(b));
        assert(a.exists!(x => x == 2));
        assert(a.forall!(x => x > 0));
        assert(a.countIf!(x => x > 1) == 2);

        // Local-capture lambda must ALSO remain @nogc (no closure allocation!)
        int threshold = 2;
        assert(a.exists!(x => x > threshold));
        assert(a.countIf!(x => x >= threshold) == 2);

        int sum = 0;
        foreach (x; a) {
            sum += x;
        }
        assert(sum == 6);

        auto r = a[];
        int sum2 = 0;
        while (!r.empty) {
            sum2 += r.front;
            r.popFront();
        }
        assert(sum2 == 6);

        // Copying a Set!int is O(1) and @nogc
        auto copyRef = a;
        assert(copyRef.length == 3);
    }

    // Mutating clear() is also pure nothrow @safe @nogc
    static void checkClearNoGC(ref Set!int s) pure nothrow @safe @nogc {
        s.clear();
        assert(s.empty);
    }

    // Allocating operations must still be pure @safe (and nothrow where applicable)
    static Set!int checkPureSafe() pure @safe {
        auto s = set(1, 2, 3);
        s.add(4);
        s.addAll(5, 6);
        s.remove(6);
        s.toggle(1);
        s.retain!(x => x >= 2);
        auto other = set(3, 4, 10);
        auto u = (s | other) - (s & set(2));
        auto f = u.filterSet!(x => x > 2).mapSet!(x => x * 10);
        auto p = f.partitionSet!(x => x >= 50);
        return p.matching | p.rest;
    }

    auto a = set(1, 2, 3);
    auto b = set(3, 4);
    checkNoGC(a, b);
    checkClearNoGC(b);
    assert(b.empty);

    auto res = checkPureSafe();
    assert(res == set(30, 40, 50, 100));
}

@("CTFE support")
unittest {
    static Set!int buildAtCompileTime() {
        auto a = set(1, 2, 3, 4);
        auto b = set(3, 4, 5);
        auto res = (a | b) - set(1);
        res.add(10);
        res.remove(2);
        res.retain!(x => x >= 4);
        return res;
    }

    enum ctfeSet = buildAtCompileTime();
    static assert(ctfeSet.length == 3);
    static assert(4 in ctfeSet && 5 in ctfeSet && 10 in ctfeSet);
    static assert(1 !in ctfeSet && 3 !in ctfeSet);
    static assert(ctfeSet.isSupersetOf(set(4, 5)));
    static assert(ctfeSet.exists!(x => x == 10));
    static assert(ctfeSet.forall!(x => x >= 4));
    static assert(ctfeSet.countIf!(x => x >= 5) == 2);
    static assert(ctfeSet.mapSet!(x => x * 2) == set(8, 10, 20));
    static assert(ctfeSet.filterSet!(x => x > 4) == set(5, 10));
    static assert(ctfeSet.filterNot!(x => x > 4) == set(4));

    enum formattedSingle = set(7).to!string;
    static assert(formattedSingle == "Set(7)");
}

@("works with diverse element types: structs, @disable this(), const fields, enums, classes, const sets of classes")
unittest {
    // Plain value structs
    auto pts = set(Point(1, 2), Point(3, 4), Point(1, 2));
    assert(pts.length == 2);
    assert(Point(1, 2) in pts);

    // Struct with @disable this()
    auto nd = Set!NoDefault(NoDefault(1), NoDefault(2));
    assert(nd.length == 2);
    assert(NoDefault(1) in nd);
    assert(nd.mapSet!(x => x.id) == set(1, 2));

    // Struct with const fields
    auto cm = Set!ConstMember(ConstMember(10), ConstMember(20));
    assert(cm.length == 2);
    assert(cm.retain!(x => x.id > 15) == 1);
    assert(ConstMember(20) in cm);

    // Enums
    auto colors = set(Color.red, Color.blue);
    assert(Color.red in colors && Color.green !in colors);

    // Classes with non-pure / non-@safe Object.opEquals
    auto w1 = new Widget(1);
    auto w2 = new Widget(2);
    auto w3 = new Widget(3);
    auto ws = set(w1, w2);
    assert(ws.length == 2);
    assert(new Widget(1) in ws);
    assert(w3 !in ws);

    auto ws2 = set(w2, w3);
    auto u = ws | ws2;
    static assert(is(typeof(u) == Set!Widget));
    assert(u.length == 3);
    assert(ws.array.length == 2);

    // const Set!Widget preserves constness on dup, array, and set operations
    const cws = ws;
    auto cdup = cws.dup;
    static assert(is(typeof(cdup) == Set!(const(Widget))));
    assert(cdup.length == 2);

    auto carr = cws.array;
    static assert(is(typeof(carr) == const(Widget)[]));
    assert(carr.length == 2);

    auto cu = cws | ws2;
    static assert(is(typeof(cu) == Set!(const(Widget))));
    assert(cu.length == 3);

    // idup is only enabled when const(T) converts to immutable(T)
    static assert(!__traits(compiles, cws.idup));
    static assert(__traits(compiles, set(1, 2).idup));
    static assert(__traits(compiles, set("a", "b").idup));
}
