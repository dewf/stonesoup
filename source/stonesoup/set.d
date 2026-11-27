module stonesoup.set;

import stonesoup.unit : Unit;

import std.functional : unaryFun;
import std.range.primitives : ElementType, isInfinite, isInputRange, isOutputRange;
import std.traits : CommonType, CopyTypeQualifiers, Unqual;

private {
    enum bool isSet(X) = is(Unqual!X == Set!U, U);

    template SetElement(S) if (isSet!S) {
        static if (is(Unqual!S == Set!U, U)) {
            alias SetElement = CopyTypeQualifiers!(S, U);
        }
    }

    template ResultElement(E) {
        static if (is(E : Unqual!E)) {
            alias ResultElement = Unqual!E;
        } else {
            alias ResultElement = E;
        }
    }

    template CombinedElement(S1, S2) if (isSet!S1 && isSet!S2) {
        alias CombinedElement = ResultElement!(CommonType!(SetElement!S1, SetElement!S2));
    }

    enum bool isCompatibleSet(S, T) = isSet!S && is(Unqual!(SetElement!S) == Unqual!T);
}

/**
 * An unordered mathematical set of unique elements of type `T`, backed by D's
 * built-in associative array (`Unit[T]`).
 *
 * Semantics:
 * - **Reference semantics**, matching D's built-in associative arrays (`V[K]`):
 *   copying a `Set!T` is O(1), `@nogc`, and aliases the underlying hash table.
 *   Use `.dup` (or `.idup`) to obtain an independent copy. As with built-in AAs
 *   and slices, a default-initialized empty `Set!T` allocates lazily on first
 *   insertion and does not alias copies made while still uninitialized.
 * - **Attribute inference**: operations automatically infer `pure`, `nothrow`,
 *   `@safe`, and `@nogc` according to what `T` and the operation permit.
 * - **Range & iteration**: `set[]` (and `set.byElement`) returns a lightweight,
 *   `@nogc` forward range over the elements, and `foreach (elem; set)` works
 *   directly on mutable, `const`, and `immutable` sets.
 * - **Operators**:
 *   - `elem in set` / `elem !in set`: membership check
 *   - `a == b` / `a != b`: order-independent set equality
 *   - `if (set)` / `cast(bool) set`: truthy iff non-empty
 *   - `a | b`, `a & b`, `a - b`, `a ^ b`: union, intersection, difference,
 *     symmetric difference (also supported with a single element on the RHS)
 *   - `a |= b`, `a &= b`, `a -= b`, `a ^= b`, `a ~= b`: in-place equivalents
 *     (also supported with a single element, and `a ~= range` for input ranges)
 * - **Higher-order UFCS operations**: `exists`, `forall`, `countIf`, `filterSet`,
 *   `filterNot`, `mapSet`, `partitionSet`, `retain`, and `removeIf` are provided
 *   as module-level UFCS functions in `stonesoup.set` so lambdas never trigger
 *   dual-context deprecations, never allocate `@nogc` closures, and never collide
 *   with `std.algorithm` imports (which compose directly with `set[]`).
 */
struct Set(T)
    if (!is(T == void))
{
private:
    Unit[T] _aa;

    this(Unit[T] aa) {
        _aa = aa;
    }

    static bool sameBacking(A, B)(const auto ref A a, const auto ref B b) {
        static if (__traits(compiles, a._aa is b._aa)) {
            return a._aa is b._aa;
        } else {
            if (__ctfe) {
                return false;
            }
            return () @trusted { return cast(const(void)*) a._aa is cast(const(void)*) b._aa; }();
        }
    }

public:
    // =========================================================================
    // Constructors
    // =========================================================================

    /// Construct a set from one or more elements.
    this(T first, scope T[] rest...) {
        _aa[first] = Unit();
        foreach (elem; rest) {
            _aa[elem] = Unit();
        }
    }

    /// Construct a set from any finite input range whose elements convert to `T`.
    this(R)(R range)
        if (isInputRange!R && !isInfinite!R && !isSet!R && is(ElementType!R : T))
    {
        foreach (elem; range) {
            _aa[elem] = Unit();
        }
    }

    // =========================================================================
    // Capacity, Queries & Identity
    // =========================================================================

    /// Number of distinct elements in the set.
    size_t length() const pure nothrow @safe @nogc => _aa.length;

    /// `true` if the set contains no elements.
    bool empty() const pure nothrow @safe @nogc => _aa.length == 0;

    /// Truthy iff the set is non-empty (`if (set)`).
    bool opCast(C : bool)() const pure nothrow @safe @nogc => _aa.length != 0;

    /// Returns `true` if `value` is an element of the set.
    /// Supports heterogeneous lookup whenever `(value in _aa)` compiles
    /// (for example, looking up a `char[]` in a `Set!string`).
    bool contains(K)(auto ref K value) const
        if (__traits(compiles, (value in _aa)))
    {
        return (value in _aa) !is null;
    }

    /// Membership test (`value in set` and `value !in set`).
    bool opBinaryRight(string op : "in", K)(auto ref K value) const
        if (__traits(compiles, (value in _aa)))
    {
        return (value in _aa) !is null;
    }

    /// Order-independent set equality.
    bool opEquals(const Set!T rhs) const {
        return _aa == rhs._aa;
    }

    /// Order-independent hash value, enabling `Set!T` as an AA key or nested `Set!(Set!T)`.
    size_t toHash() const {
        return hashOf(_aa);
    }

    // =========================================================================
    // Iteration, Slicing, Copying & Formatting
    // =========================================================================

    /// Returns a lightweight `@nogc` forward range over the set's elements.
    /// Also powers `foreach (elem; set)` for mutable, `const`, and `immutable` sets.
    auto opSlice() inout pure nothrow @safe @nogc => _aa.byKey();

    /// Named equivalent of `set[]`, returning a forward range over the elements.
    auto byElement() inout pure nothrow @safe @nogc => _aa.byKey();

    /// Returns a newly allocated dynamic array containing all elements of the set
    /// (in unspecified order).
    auto array(this This)() {
        alias E = ResultElement!(SetElement!This);
        E[] result;
        if (_aa.length == 0) {
            return result;
        }
        result.reserve(_aa.length);
        foreach (k, _; _aa) {
            result ~= k;
        }
        return result;
    }

    /// Returns a shallow independent copy of the set.
    auto dup(this This)() {
        alias E = ResultElement!(SetElement!This);
        Set!E copy;
        foreach (k, _; _aa) {
            copy._aa[k] = Unit();
        }
        return copy;
    }

    static if (is(const(T) : immutable(T))) {
        /// Returns an `immutable` independent copy of the set.
        immutable(Set!T) idup() const {
            static Set!T makeCopy(const Unit[T] src) {
                Set!T copy;
                foreach (k, _; src) {
                    copy._aa[k] = Unit();
                }
                return copy;
            }
            return makeCopy(_aa);
        }
    }

    /// Sink-based string formatting for `std.format`, `writeln`, and `to!string`.
    void toString(W)(ref W writer) const
        if (isOutputRange!(W, char))
    {
        import std.format.write : formattedWrite;
        import std.range : only;
        import std.range.primitives : put;

        put(writer, "Set(");
        bool first = true;
        foreach (k, _; _aa) {
            if (!first) {
                put(writer, ", ");
            }
            first = false;
            formattedWrite(writer, "%(%s%)", only(k));
        }
        put(writer, ")");
    }

    // =========================================================================
    // Mutation
    // =========================================================================

    /// Inserts `value` into the set.
    /// Returns `true` if `value` was newly inserted, `false` if it was already present.
    bool add(T value) {
        if (value in _aa) {
            return false;
        }
        _aa[value] = Unit();
        return true;
    }

    /// Inserts one or more elements. Returns the number of newly inserted elements.
    size_t addAll(T first, scope T[] rest...) {
        size_t added = add(first) ? 1 : 0;
        foreach (elem; rest) {
            if (add(elem)) {
                ++added;
            }
        }
        return added;
    }

    /// Inserts all elements from a finite input range.
    /// Returns the number of newly inserted elements.
    size_t addAll(R)(R range)
        if (isInputRange!R && !isInfinite!R && !isSet!R && is(ElementType!R : T))
    {
        size_t added = 0;
        foreach (elem; range) {
            if (add(elem)) {
                ++added;
            }
        }
        return added;
    }

    /// Inserts all elements from another compatible set (in-place union).
    /// Returns the number of newly inserted elements.
    size_t addAll(Other)(Other other)
        if (isCompatibleSet!(Other, T) && is(SetElement!Other : T))
    {
        if (other._aa.length == 0 || sameBacking(this, other)) {
            return 0;
        }
        size_t added = 0;
        foreach (k, _; other._aa) {
            if (add(k)) {
                ++added;
            }
        }
        return added;
    }

    /// Removes `value` if present.
    /// Returns `true` if `value` was found and removed, `false` otherwise.
    bool remove(K)(auto ref K value)
        if (__traits(compiles, _aa.remove(value)))
    {
        return _aa.remove(value);
    }

    /// Removes one or more elements. Returns the number of elements actually removed.
    size_t removeAll(T first, scope T[] rest...) {
        size_t removed = _aa.remove(first) ? 1 : 0;
        foreach (elem; rest) {
            if (_aa.remove(elem)) {
                ++removed;
            }
        }
        return removed;
    }

    /// Removes all elements yielded by a finite input range.
    /// Returns the number of elements actually removed.
    size_t removeAll(R)(R range)
        if (isInputRange!R && !isInfinite!R && !isSet!R
            && __traits(compiles, { ElementType!R e; _aa.remove(e); }))
    {
        size_t removed = 0;
        foreach (elem; range) {
            if (_aa.remove(elem)) {
                ++removed;
            }
        }
        return removed;
    }

    /// Removes all elements present in `other` (in-place difference).
    /// Returns the number of elements actually removed.
    size_t removeAll(Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        if (_aa.length == 0 || other._aa.length == 0) {
            return 0;
        }
        if (sameBacking(this, other)) {
            const removed = _aa.length;
            _aa.clear();
            return removed;
        }
        size_t removed = 0;
        foreach (k, _; other._aa) {
            if (_aa.remove(k)) {
                ++removed;
            }
        }
        return removed;
    }

    /// Toggles membership of `value`: removes it if present, inserts it if absent.
    /// Returns the new membership state (`true` if now present, `false` if now absent).
    bool toggle(T value) {
        if (_aa.remove(value)) {
            return false;
        }
        _aa[value] = Unit();
        return true;
    }

    /// Keeps only elements that are also present in `other` (in-place intersection).
    /// Returns the number of elements removed.
    size_t intersectWith(Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        if (_aa.length == 0 || sameBacking(this, other)) {
            return 0;
        }
        if (other._aa.length == 0) {
            const removed = _aa.length;
            _aa.clear();
            return removed;
        }
        T[] toRemove;
        foreach (k, _; _aa) {
            if (k !in other._aa) {
                toRemove ~= k;
            }
        }
        foreach (ref k; toRemove) {
            _aa.remove(k);
        }
        return toRemove.length;
    }

    /// Replaces this set with the symmetric difference of `this` and `other` in place.
    void symmetricDifferenceWith(Other)(Other other)
        if (isCompatibleSet!(Other, T) && is(SetElement!Other : T))
    {
        if (other._aa.length == 0) {
            return;
        }
        if (sameBacking(this, other)) {
            _aa.clear();
            return;
        }
        foreach (k, _; other._aa) {
            if (!_aa.remove(k)) {
                _aa[k] = Unit();
            }
        }
    }

    /// Removes all elements from the set.
    void clear() {
        _aa.clear();
    }

    /// Reorganizes the underlying associative array for optimal lookup performance.
    void rehash() {
        _aa.rehash();
    }

    // =========================================================================
    // Set-Theoretic Predicates
    // =========================================================================

    /// Returns `true` if every element of `this` is also in `other`.
    bool isSubsetOf(Other)(Other other) const
        if (isCompatibleSet!(Other, T))
    {
        if (_aa.length > other._aa.length) {
            return false;
        }
        if (_aa.length == 0 || sameBacking(this, other)) {
            return true;
        }
        foreach (k, _; _aa) {
            if (k !in other._aa) {
                return false;
            }
        }
        return true;
    }

    /// Returns `true` if `this` is a strict subset of `other` (`this ⊂ other`).
    bool isProperSubsetOf(Other)(Other other) const
        if (isCompatibleSet!(Other, T))
    {
        return _aa.length < other._aa.length && isSubsetOf(other);
    }

    /// Returns `true` if every element of `other` is also in `this`.
    bool isSupersetOf(Other)(Other other) const
        if (isCompatibleSet!(Other, T))
    {
        return other.isSubsetOf(this);
    }

    /// Returns `true` if `this` is a strict superset of `other` (`this ⊃ other`).
    bool isProperSupersetOf(Other)(Other other) const
        if (isCompatibleSet!(Other, T))
    {
        return other.isProperSubsetOf(this);
    }

    /// Returns `true` if `this` and `other` share no elements in common.
    bool isDisjointWith(Other)(Other other) const
        if (isCompatibleSet!(Other, T))
    {
        if (_aa.length == 0 || other._aa.length == 0) {
            return true;
        }
        if (sameBacking(this, other)) {
            return false;
        }
        if (_aa.length <= other._aa.length) {
            foreach (k, _; _aa) {
                if (k in other._aa) {
                    return false;
                }
            }
        } else {
            foreach (k, _; other._aa) {
                if (k in _aa) {
                    return false;
                }
            }
        }
        return true;
    }

    // =========================================================================
    // Non-Mutating Set Algebra
    // =========================================================================

    /// Returns a new set containing all elements present in `this`, `other`, or both.
    auto setUnion(this This, Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        alias E = CombinedElement!(This, Other);
        Set!E result;
        foreach (k, _; _aa) {
            result._aa[k] = Unit();
        }
        if (!sameBacking(this, other)) {
            foreach (k, _; other._aa) {
                result._aa[k] = Unit();
            }
        }
        return result;
    }

    /// Returns a new set containing only elements present in both `this` and `other`.
    auto intersection(this This, Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        alias E = CombinedElement!(This, Other);
        Set!E result;
        if (_aa.length == 0 || other._aa.length == 0) {
            return result;
        }
        if (sameBacking(this, other)) {
            foreach (k, _; _aa) {
                result._aa[k] = Unit();
            }
            return result;
        }
        if (_aa.length <= other._aa.length) {
            foreach (k, _; _aa) {
                if (k in other._aa) {
                    result._aa[k] = Unit();
                }
            }
        } else {
            foreach (k, _; other._aa) {
                if (k in _aa) {
                    result._aa[k] = Unit();
                }
            }
        }
        return result;
    }

    /// Returns a new set containing elements in `this` that are not in `other` (`this \ other`).
    auto difference(this This, Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        alias E = ResultElement!(SetElement!This);
        Set!E result;
        if (_aa.length == 0 || sameBacking(this, other)) {
            return result;
        }
        foreach (k, _; _aa) {
            if (k !in other._aa) {
                result._aa[k] = Unit();
            }
        }
        return result;
    }

    /// Returns a new set containing elements in either `this` or `other`, but not both.
    auto symmetricDifference(this This, Other)(Other other)
        if (isCompatibleSet!(Other, T))
    {
        alias E = CombinedElement!(This, Other);
        Set!E result;
        if (sameBacking(this, other)) {
            return result;
        }
        foreach (k, _; _aa) {
            if (k !in other._aa) {
                result._aa[k] = Unit();
            }
        }
        foreach (k, _; other._aa) {
            if (k !in _aa) {
                result._aa[k] = Unit();
            }
        }
        return result;
    }

    // =========================================================================
    // Operator Overloads
    // =========================================================================

    /// Binary set-set operations: `|` (union), `&` (intersection),
    /// `-` (difference), `^` (symmetric difference).
    auto opBinary(string op, this This, Other)(Other rhs)
        if ((op == "|" || op == "&" || op == "-" || op == "^")
            && isCompatibleSet!(Other, T))
    {
        static if (op == "|") {
            return setUnion(rhs);
        } else static if (op == "&") {
            return intersection(rhs);
        } else static if (op == "-") {
            return difference(rhs);
        } else static if (op == "^") {
            return symmetricDifference(rhs);
        }
    }

    /// Binary set-element operations (equivalent to combining with singleton `{rhs}`):
    /// - `set | elem`: copy with `elem` added
    /// - `set - elem`: copy with `elem` removed
    /// - `set ^ elem`: copy with `elem` toggled
    /// - `set & elem`: `{elem}` if `elem in set`, else empty set
    auto opBinary(string op, this This, U)(auto ref U rhs)
        if ((op == "|" || op == "&" || op == "-" || op == "^")
            && !isCompatibleSet!(U, T)
            && is(U : ResultElement!(SetElement!This)))
    {
        alias E = ResultElement!(SetElement!This);
        static if (op == "|") {
            auto result = dup();
            result._aa[rhs] = Unit();
            return result;
        } else static if (op == "-") {
            auto result = dup();
            result._aa.remove(rhs);
            return result;
        } else static if (op == "^") {
            auto result = dup();
            if (!result._aa.remove(rhs)) {
                result._aa[rhs] = Unit();
            }
            return result;
        } else static if (op == "&") {
            Set!E result;
            if (rhs in _aa) {
                result._aa[rhs] = Unit();
            }
            return result;
        }
    }

    /// Compound assignment with another set: `|=`, `~=`, `&=`, `-=`, `^=`.
    ref Set!T opOpAssign(string op, Other)(Other rhs) return
        if ((op == "|" || op == "~" || op == "&" || op == "-" || op == "^")
            && isCompatibleSet!(Other, T)
            && ((op != "|" && op != "~" && op != "^") || is(SetElement!Other : T)))
    {
        static if (op == "|" || op == "~") {
            addAll(rhs);
        } else static if (op == "&") {
            intersectWith(rhs);
        } else static if (op == "-") {
            removeAll(rhs);
        } else static if (op == "^") {
            symmetricDifferenceWith(rhs);
        }
        return this;
    }

    /// Compound assignment with a single element:
    /// - `set ~= elem` / `set |= elem`: insert `elem`
    /// - `set -= elem`: remove `elem`
    /// - `set ^= elem`: toggle `elem`
    /// - `set &= elem`: keep only `elem` if present, otherwise empty the set
    ref Set!T opOpAssign(string op, U)(auto ref U rhs) return
        if ((op == "~" || op == "|" || op == "&" || op == "-" || op == "^")
            && !isCompatibleSet!(U, T)
            && ((op == "-" && __traits(compiles, _aa.remove(rhs)))
                || (op != "-" && is(U : T))))
    {
        static if (op == "~" || op == "|") {
            _aa[rhs] = Unit();
        } else static if (op == "-") {
            _aa.remove(rhs);
        } else static if (op == "^") {
            toggle(rhs);
        } else static if (op == "&") {
            if (rhs in _aa) {
                if (_aa.length > 1) {
                    _aa.clear();
                    _aa[rhs] = Unit();
                }
            } else {
                _aa.clear();
            }
        }
        return this;
    }

    /// Append all elements from a finite input range (`set ~= range`).
    ref Set!T opOpAssign(string op : "~", R)(R range) return
        if (!isCompatibleSet!(R, T) && !is(R : T) && isInputRange!R && !isInfinite!R
            && is(ElementType!R : T))
    {
        addAll(range);
        return this;
    }
}

// =============================================================================
// Higher-Order UFCS Queries & Transformations (Scala-inspired)
// =============================================================================
// Defined as free functions with names that do not collide with `std.algorithm`
// (which composes directly with `set[]`), so `alias pred` / `alias fun` lambdas
// never require a dual-context pointer (avoiding deprecations and `@nogc`
// closure allocations) and never get shadowed by selective `std.algorithm` imports.

/// Returns `true` if at least one element in `s` satisfies `pred` (Scala `Set.exists`).
bool exists(alias pred, S)(const auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!pred;
    foreach (k, _; s._aa) {
        if (fn(k)) {
            return true;
        }
    }
    return false;
}

/// Returns `true` if every element in `s` satisfies `pred` (Scala `Set.forall`,
/// vacuously `true` when empty).
bool forall(alias pred, S)(const auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!pred;
    foreach (k, _; s._aa) {
        if (!fn(k)) {
            return false;
        }
    }
    return true;
}

/// Returns the number of elements in `s` satisfying `pred`.
size_t countIf(alias pred, S)(const auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!pred;
    size_t n = 0;
    foreach (k, _; s._aa) {
        if (fn(k)) {
            ++n;
        }
    }
    return n;
}

/// Retains only elements in `s` satisfying `pred`, removing all others in place.
/// Safe against AA iteration invalidation. Returns the number of elements removed.
size_t retain(alias pred, T)(ref Set!T s) {
    alias fn = unaryFun!pred;
    if (s._aa.length == 0) {
        return 0;
    }
    T[] toRemove;
    foreach (k, _; s._aa) {
        if (!fn(k)) {
            toRemove ~= k;
        }
    }
    foreach (ref k; toRemove) {
        s._aa.remove(k);
    }
    return toRemove.length;
}

/// Removes all elements in `s` satisfying `pred` in place (the inverse of `retain`).
/// Safe against AA iteration invalidation. Returns the number of elements removed.
size_t removeIf(alias pred, T)(ref Set!T s) {
    alias fn = unaryFun!pred;
    if (s._aa.length == 0) {
        return 0;
    }
    T[] toRemove;
    foreach (k, _; s._aa) {
        if (fn(k)) {
            toRemove ~= k;
        }
    }
    foreach (ref k; toRemove) {
        s._aa.remove(k);
    }
    return toRemove.length;
}

/// Returns a new set containing only elements of `s` satisfying `pred`.
auto filterSet(alias pred, S)(auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!pred;
    alias E = ResultElement!(SetElement!S);
    Set!E result;
    foreach (k, _; s._aa) {
        if (fn(k)) {
            result._aa[k] = Unit();
        }
    }
    return result;
}

/// Returns a new set containing only elements of `s` NOT satisfying `pred` (Scala `Set.filterNot`).
auto filterNot(alias pred, S)(auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!pred;
    alias E = ResultElement!(SetElement!S);
    Set!E result;
    foreach (k, _; s._aa) {
        if (!fn(k)) {
            result._aa[k] = Unit();
        }
    }
    return result;
}

/// Returns a new set containing the results of applying `fun` to each element of `s`.
auto mapSet(alias fun, S)(auto ref S s)
    if (isSet!S)
{
    alias fn = unaryFun!fun;
    alias SrcE = SetElement!S;
    static if (is(typeof(fn(*(SrcE*).init)) U)) {
        alias DstE = ResultElement!U;
    } else {
        static assert(false, "mapSet function must be callable with " ~ SrcE.stringof);
    }
    Set!DstE result;
    foreach (k, _; s._aa) {
        result._aa[fn(k)] = Unit();
    }
    return result;
}

/// Splits `s` in a single pass into two sets: `.matching` (elements where
/// `pred` is true) and `.rest` (elements where `pred` is false).
auto partitionSet(alias pred, S)(auto ref S s)
    if (isSet!S)
{
    import std.typecons : Tuple;
    alias fn = unaryFun!pred;
    alias E = ResultElement!(SetElement!S);
    Tuple!(Set!E, "matching", Set!E, "rest") result;
    foreach (k, _; s._aa) {
        if (fn(k)) {
            result.matching._aa[k] = Unit();
        } else {
            result.rest._aa[k] = Unit();
        }
    }
    return result;
}

// =============================================================================
// Convenience Factory Functions
// =============================================================================

/// Creates an empty `Set!T`.
Set!T set(T)() pure nothrow @safe @nogc
    if (!is(T == void))
{
    return Set!T.init;
}

/// Creates a `Set` from one or more elements, inferring the element type automatically.
auto set(Args...)(Args args)
    if (Args.length > 0 && !is(CommonType!Args == void))
{
    alias E = ResultElement!(CommonType!Args);
    Set!E result;
    static foreach (i; 0 .. Args.length) {
        result.add(args[i]);
    }
    return result;
}

/// Converts any finite input range into a `Set`, inferring the element type.
auto toSet(R)(R range)
    if (isInputRange!R && !isInfinite!R && !is(ElementType!R == void))
{
    alias E = ResultElement!(ElementType!R);
    return Set!E(range);
}

/// Converts any finite input range into a `Set!T` with an explicit element type `T`.
Set!T toSet(T, R)(R range)
    if (!is(T == void) && isInputRange!R && !isInfinite!R && is(ElementType!R : T))
{
    return Set!T(range);
}
