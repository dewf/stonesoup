module stonesoup.set;

import stonesoup.unit;

import std.range : ElementType;

struct Set(T) {
private:
    Unit[T] items;

public:
    // just for convenience/aesthetics
    static Set!T empty() => Set!T();

    this(Range)(Range r)
        if (is(ElementType!Range == T))
    {
        foreach (v; r) {
            items[v] = Unit();
        }
    }

    this(T[] values...) {
        foreach (v; values) {
            items[v] = Unit();
        }
    }

    this(ref return scope const(Set!T) rhs) {
        items = rhs.items.dup;
    }

    size_t length() const {
        return items.length;
    }

    bool isEmpty() const {
        return items.length == 0;
    }

    Set!T dup() const {
        Set!T ret;
        ret.items = items.dup();
        return ret;
    }

    void clear() {
        items.clear;
    }

    ref Set!T opAssign(Set!T rhs) return {
        items = rhs.items;
        return this;
    }

    // to avoid errors copying a ref const(Set) to a non-const
    ref Set!T opAssign()(auto ref const(Set!T) rhs) return {
        items = rhs.items.dup;
        return this;
    }

    void set()(auto ref T rhs) {
        items[rhs] = Unit();
    }

    void opOpAssign(string op)(T rhs) if (op == "~") {
        set(rhs);
    }

    void set()(T[] toAdd...) {
        foreach (r; toAdd) {
            items[r] = Unit();
        }
    }

    void clearExcept(T rhs) {
        const present = (rhs in items) != null;
        items.clear();
        if (present) items[rhs] = Unit();
    }

    void remove(T rhs) {
        items.remove(rhs);
    }

    void opOpAssign(string op)(auto ref T rhs) if (op == "-") { // ie, 'and' ('not' rhs)
        remove(rhs);
    }

    bool contains(T rhs) const {
        return (rhs in items) != null;
    }

    string toString() const {
        import std.conv: to;
        return items.keys.to!string;
    }

    // foreach capability
    int opApply(int delegate(ref const(T)) dg) {
        int result = 0;
        foreach (ref k; items.byKey) {
            result = dg(k);
            if (result != 0) {
                break;
            }
        }
        return result;
    }

    T[] array() const {
        return items.keys;
    }

    // bitwise operators for convenience
    void opOpAssign(string op)(T rhs) if (op == "|") { // |=
        set(rhs);
    }

    void opOpAssign(string op)(T rhs) if (op == "&") { // &=
        clearExcept(rhs);
    }

    bool opBinary(string op)(T rhs) const if (op == "&") {
        return contains(rhs);
    }

    // set operations
    // TODO: operator overloads?
    Set!T union_()(auto ref const(Set!T) rhs) const {
        Set!T result;
        foreach (k, v; items) {
            result.set(k);
        }
        foreach (k, v; rhs.items) {
            result.set(k);
        }
        return result;
    }

    Set!T intersect()(auto ref const(Set!T) rhs) const {
        Set!T result;
        foreach (k, v; rhs.items) {
            if (k in items) {
                result.set(k);
            }
        }
        return result;
    }
}
