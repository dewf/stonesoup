module refcounted_tests;

import stonesoup.disposable : IDisposable;
import stonesoup.refcounted : RefCounted, refCounted, makeRefCounted;

import std.algorithm.mutation : move;
import std.conv : to;
import std.exception : assertThrown;

private {
    interface IResource : IDisposable {
        string label() const;
    }

    abstract class BaseResource : IResource {
        int disposeCount;
        override void dispose() {
            ++disposeCount;
        }
    }

    class DefaultOnly : IDisposable {
        int disposeCount;
        int value = 7;
        override void dispose() {
            ++disposeCount;
        }
    }

    class Resource : BaseResource {
        string name;
        int count;

        this() {
            name = "default";
            count = 0;
        }

        this(string name) {
            this.name = name;
            this.count = 1;
        }

        this(string name, int count) {
            this.name = name;
            this.count = count;
        }

        override string label() const => name;

        void reset() {
            count = 0;
        }

        void release() {
            name = "released";
        }

        override string toString() const => "Resource(" ~ name ~ ")";
    }

    class NoDefaultCtor : BaseResource {
        string name;

        this(string name) {
            this.name = name;
        }

        override string label() const => name;
    }

    class CopyCtorClass : IDisposable {
        int id;
        int disposeCount;

        this(int id) {
            this.id = id;
        }

        this(CopyCtorClass other) {
            this.id = other.id + 100;
        }

        override void dispose() {
            ++disposeCount;
        }
    }

    struct NonCopyable {
        int value;
        @disable this(this);
    }

    class FancyCtors : IDisposable {
        int value;
        string tag;
        int disposeCount;

        this(ref int counter) {
            counter += 10;
            value = counter;
        }

        this(NonCopyable nc) {
            value = nc.value;
        }

        this(int a, string b = "fallback") {
            value = a;
            tag = b;
        }

        this(string tag, int[] nums...) {
            this.tag = tag;
            foreach (n; nums) {
                value += n;
            }
        }

        this(U)(U x) if (is(U == double)) {
            value = cast(int)(x * 10);
        }

        override void dispose() {
            ++disposeCount;
        }
    }

    class DependentService : IDisposable {
        RefCounted!Resource res;
        int disposeCount;

        this(RefCounted!Resource res) {
            this.res = res;
        }

        override void dispose() {
            ++disposeCount;
            res = null;
        }
    }

    class ThrowingDisposable : IDisposable {
        int disposeCount;

        override void dispose() {
            ++disposeCount;
            throw new Exception("dispose failed");
        }
    }

    class NotDisposable {}

    struct DisposableStruct {
        Resource r;
        alias r this;
        void dispose() {}
    }
}

@("RefCounted template constraints")
unittest {
    static assert(__traits(compiles, RefCounted!IDisposable));
    static assert(__traits(compiles, RefCounted!IResource));
    static assert(__traits(compiles, RefCounted!BaseResource));
    static assert(__traits(compiles, RefCounted!Resource));

    static assert(!__traits(compiles, RefCounted!NotDisposable));
    static assert(!__traits(compiles, RefCounted!DisposableStruct));
    static assert(!__traits(compiles, RefCounted!int));
    static assert(!__traits(compiles, RefCounted!string));
}

@("RefCounted basic lifecycle and disposal at zero")
unittest {
    auto raw = new Resource("alpha", 10);
    {
        auto a = RefCounted!Resource(raw);
        assert(a.refCount == 1);
        assert(!a.isNull);
        assert(cast(bool) a);
        assert(raw.disposeCount == 0);

        {
            auto b = a;
            assert(a.refCount == 2);
            assert(b.refCount == 2);
            assert(raw.disposeCount == 0);

            auto c = RefCounted!Resource(b);
            assert(a.refCount == 3);
            assert(c.refCount == 3);
        }

        assert(a.refCount == 1);
        assert(raw.disposeCount == 0);
    }
    assert(raw.disposeCount == 1);
}

@("RefCounted default init and explicit null")
unittest {
    RefCounted!Resource empty;
    assert(empty.isNull);
    assert(!empty);
    assert(empty.refCount == 0);
    assert(empty == null);
    assert(null == empty);
    assert(empty.unwrap is null);

    auto explicitNull = RefCounted!Resource(null);
    assert(explicitNull.isNull);
    assert(explicitNull.refCount == 0);
    assert(explicitNull == empty);

    // Copying null RefCounted stays null
    auto copyNull = empty;
    assert(copyNull.isNull);
    assert(copyNull.refCount == 0);
}

@("RefCounted direct class construction via T constructors")
unittest {
    // Implicit default constructor (no explicit ctor on class)
    {
        auto d = RefCounted!DefaultOnly();
        assert(d.refCount == 1);
        assert(d.value == 7);
    }

    // Explicit 0-arg, 1-arg, and 2-arg constructors
    {
        auto r0 = RefCounted!Resource();
        assert(r0.refCount == 1);
        assert(r0.name == "default" && r0.count == 0);

        auto r1 = RefCounted!Resource("one");
        assert(r1.refCount == 1);
        assert(r1.name == "one" && r1.count == 1);

        auto r2 = RefCounted!Resource("two", 42);
        assert(r2.refCount == 1);
        assert(r2.name == "two" && r2.count == 42);
    }

    // Direct construction rejected for classes without matching ctor, abstract classes, and interfaces
    static assert(!__traits(compiles, RefCounted!NoDefaultCtor()));
    static assert(!__traits(compiles, RefCounted!BaseResource()));
    static assert(!__traits(compiles, RefCounted!IResource()));
    static assert(!__traits(compiles, RefCounted!IDisposable()));
}

@("RefCounted forwards ref, non-copyable, default, variadic, and templated ctor args")
unittest {
    int counter = 5;
    auto byRef = RefCounted!FancyCtors(counter);
    assert(counter == 15);
    assert(byRef.value == 15);

    auto byMove = RefCounted!FancyCtors(NonCopyable(99));
    assert(byMove.value == 99);

    auto withDef = RefCounted!FancyCtors(12);
    assert(withDef.value == 12 && withDef.tag == "fallback");

    auto withExplicit = RefCounted!FancyCtors(12, "given");
    assert(withExplicit.value == 12 && withExplicit.tag == "given");

    auto withVarargs = RefCounted!FancyCtors("sum", 1, 2, 3, 4);
    assert(withVarargs.tag == "sum" && withVarargs.value == 10);

    auto withTemplate = RefCounted!FancyCtors(3.5);
    assert(withTemplate.value == 35);
}

@("RefCounted wrapping existing instance vs makeRefCounted with copy-like ctor")
unittest {
    auto raw = new CopyCtorClass(5);
    {
        // RefCounted!T(raw) wraps existing instance rather than calling CopyCtorClass(raw)
        auto wrapped = RefCounted!CopyCtorClass(raw);
        assert(wrapped.id == 5);
        assert(wrapped.refCount == 1);

        // makeRefCounted explicitly invokes new CopyCtorClass(raw)
        auto copied = makeRefCounted!CopyCtorClass(raw);
        assert(copied.id == 105);
        assert(copied.refCount == 1);
        assert(wrapped.refCount == 1);
    }
    assert(raw.disposeCount == 1);
}

@("RefCounted constructor accepting another RefCounted type")
unittest {
    auto rawRes = new Resource("dep", 3);
    {
        auto res = RefCounted!Resource(rawRes);
        auto svc = RefCounted!DependentService(res);
        assert(res.refCount == 2);
        assert(svc.refCount == 1);
        assert(svc.res.name == "dep");
        res = null;
        assert(rawRes.disposeCount == 0);
        assert(svc.res.refCount == 1);
    }
    assert(rawRes.disposeCount == 1);
}

@("RefCounted interface wrapping and polymorphic upcasting")
unittest {
    auto raw = new Resource("poly", 5);
    {
        auto r = RefCounted!Resource(raw);
        assert(r.refCount == 1);

        auto base = RefCounted!BaseResource(r);
        assert(r.refCount == 2);
        assert(base.refCount == 2);

        auto iface = RefCounted!IResource(r);
        assert(r.refCount == 3);
        assert(iface.label() == "poly");

        RefCounted!IDisposable disp;
        disp = r;
        assert(r.refCount == 4);
        assert(disp.refCount == 4);

        r = null;
        base = null;
        iface = null;
        assert(disp.refCount == 1);
        assert(raw.disposeCount == 0);
    }
    assert(raw.disposeCount == 1);

    // Direct interface wrapping via refCounted helper
    auto raw2 = new NoDefaultCtor("iface-direct");
    {
        IResource asIface = raw2;
        auto rc = refCounted(asIface);
        assert(rc.refCount == 1);
        assert(rc.label() == "iface-direct");
    }
    assert(raw2.disposeCount == 1);
}

@("RefCounted assignment, self-assignment, and reassignment disposal")
unittest {
    auto raw1 = new Resource("first");
    auto raw2 = new Resource("second");
    {
        auto a = RefCounted!Resource(raw1);
        auto b = RefCounted!Resource(raw2);

        // Self-assignment must not dispose
        a = a;
        assert(a.refCount == 1);
        assert(raw1.disposeCount == 0);

        // Reassigning a to b disposes raw1 and shares raw2
        a = b;
        assert(raw1.disposeCount == 1);
        assert(raw2.disposeCount == 0);
        assert(a.refCount == 2);
        assert(b.refCount == 2);
        assert(a.name == "second");

        // Assigning null decrements without disposing while b still holds it
        a = null;
        assert(a.isNull);
        assert(b.refCount == 1);
        assert(raw2.disposeCount == 0);
    }
    assert(raw2.disposeCount == 1);
}

@("RefCounted passing by value, ref, and returning from functions")
unittest {
    static RefCounted!Resource makeOne(string name) {
        return RefCounted!Resource(name, 99);
    }

    static size_t inspectByValue(RefCounted!Resource r) {
        return r.refCount;
    }

    static size_t inspectByRef(ref RefCounted!Resource r) {
        return r.refCount;
    }

    auto raw = new Resource("func");
    {
        auto rc = RefCounted!Resource(raw);
        assert(inspectByValue(rc) == 2);
        assert(rc.refCount == 1);
        assert(inspectByRef(rc) == 1);
        assert(rc.refCount == 1);
        assert(raw.disposeCount == 0);
    }
    assert(raw.disposeCount == 1);

    auto created = makeOne("returned");
    assert(created.refCount == 1);
    assert(created.name == "returned" && created.count == 99);
}

@("RefCounted alias this does not shadow reset/release on T")
unittest {
    auto rc = RefCounted!Resource("alive", 123);
    rc.reset();
    assert(rc.count == 0);
    assert(rc.refCount == 1);
    rc.release();
    assert(rc.name == "released");
    assert(rc.refCount == 1);
}

@("RefCounted equality, toHash, AA key compatibility, and toString")
unittest {
    auto a = RefCounted!Resource("same");
    auto b = a;
    auto iface = RefCounted!IResource(a);
    auto other = RefCounted!Resource("same");
    RefCounted!Resource empty;

    assert(a == b);
    assert(a == iface);
    assert(iface == a);
    assert(a != other);
    assert(iface != other);
    assert(a != null);
    assert(null != a);
    assert(empty == null);
    assert(empty != a);

    // Compatible with associative arrays
    int[RefCounted!Resource] map;
    map[a] = 1;
    map[b] = 2;
    map[other] = 3;
    assert(map.length == 2);
    assert(map[a] == 2);
    assert(map[other] == 3);

    // toString handles both non-null and null safely
    assert(a.to!string == "Resource(same)");
    assert(iface.to!string == "Resource(same)");
    assert(empty.to!string == "null");
}

@("RefCounted const usage")
unittest {
    auto raw = new Resource("const-test");
    {
        auto rc = RefCounted!Resource(raw);
        const crc = rc;
        assert(crc.label() == "const-test");
        assert(crc.refCount == 2);
        assert(!crc.isNull);
        assert(crc == rc);
        assert(crc.to!string == "Resource(const-test)");
    }
    assert(raw.disposeCount == 1);
}

@("RefCounted move and destroy")
unittest {
    auto raw1 = new Resource("moved");
    {
        auto a = refCounted(raw1);
        auto b = move(a);
        assert(a.isNull && a.refCount == 0);
        assert(!b.isNull && b.refCount == 1);
        assert(raw1.disposeCount == 0);
    }
    assert(raw1.disposeCount == 1);

    auto raw2 = new Resource("destroyed");
    {
        auto a = refCounted(raw2);
        destroy(a);
        assert(a.isNull && a.refCount == 0);
        assert(raw2.disposeCount == 1);
    }
    assert(raw2.disposeCount == 1);
}

@("RefCounted non-static local class wrapping")
unittest {
    int disposed = 0;
    class Local : IDisposable {
        override void dispose() {
            ++disposed;
        }
    }
    {
        auto rc = RefCounted!Local(new Local());
        assert(rc.refCount == 1);
    }
    assert(disposed == 1);
}

@("RefCounted exception safety when dispose throws")
unittest {
    auto raw = new ThrowingDisposable();
    {
        auto rc = RefCounted!ThrowingDisposable(raw);
        assertThrown!Exception(rc = null);
        assert(rc.isNull);
        assert(rc.refCount == 0);
        assert(raw.disposeCount == 1);
    }
    // Scope exit must not double-dispose
    assert(raw.disposeCount == 1);
}

@("RefCounted inside structs and dynamic arrays")
unittest {
    struct Holder {
        RefCounted!Resource res;
    }

    auto raw = new Resource("held");
    {
        Holder h1 = Holder(RefCounted!Resource(raw));
        assert(h1.res.refCount == 1);
        Holder h2 = h1;
        assert(h1.res.refCount == 2);
        assert(raw.disposeCount == 0);

        RefCounted!Resource[] arr;
        arr ~= h1.res;
        assert(h1.res.refCount == 3);
        arr[0] = null;
        assert(h1.res.refCount == 2);
    }
    assert(raw.disposeCount == 1);
}
