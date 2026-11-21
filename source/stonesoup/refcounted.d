module stonesoup.refcounted;

// written by Gemini 4 Neon (High) on 2026-11-20

import stonesoup.disposable : IDisposable;

import std.algorithm.mutation : swap;
import std.functional : forward;
import std.traits : Unqual;

private enum isRefCounted(X) = is(Unqual!X == RefCounted!U, U);

/**
 * Reference-counted smart wrapper for classes and interfaces implementing `IDisposable`.
 *
 * Automatically invokes `.dispose()` on the wrapped instance once the last
 * `RefCounted!T` referencing it is destroyed or reassigned.
 *
 * If `T` is a concrete (non-abstract) class, `RefCounted!T` can be constructed
 * directly with any arguments accepted by `T`'s constructors (including 0-arg
 * construction via `RefCounted!T()`), as well as by wrapping an existing `T`
 * instance (`RefCounted!T(existing)`).
 */
struct RefCounted(T)
    if ((is(T == class) || is(T == interface)) && is(T : IDisposable))
{
private:
    T _payload;
    size_t* _refCount;

    static RefCounted!T fromParts(T payload, size_t* refCount) {
        RefCounted!T rc;
        rc._payload = payload;
        rc._refCount = refCount;
        return rc;
    }

    void _release() {
        if (_refCount !is null) {
            auto count = _refCount;
            auto payload = _payload;
            _refCount = null;
            _payload = null;
            if (--(*count) == 0 && payload !is null) {
                payload.dispose();
            }
        } else {
            _payload = null;
        }
    }

public:
    inout(T) unwrap() inout => _payload;
    alias unwrap this;

    size_t refCount() const => _refCount !is null ? *_refCount : 0;

    bool isNull() const => _payload is null;

    bool opCast(C : bool)() const => _payload !is null;

    bool opEquals(typeof(null)) const => _payload is null;

    bool opEquals(U)(const auto ref RefCounted!U rhs) const
        if (is(U : T) || is(T : U))
    {
        if (_payload is null && rhs._payload is null) {
            return true;
        }
        if (_payload is null || rhs._payload is null) {
            return false;
        }
        return cast(const(Object)) _payload is cast(const(Object)) rhs._payload;
    }

    size_t toHash() const nothrow @trusted {
        if (_payload is null) {
            return 0;
        }
        return hashOf(cast(const(void)*) cast(const(Object)) _payload);
    }

    string toString() {
        if (_payload is null) {
            return "null";
        }
        import std.conv : to;
        static if (is(T == interface) && !__traits(compiles, _payload.toString())) {
            auto obj = cast(Object) _payload;
            return obj !is null ? obj.toString() : "null";
        } else {
            return _payload.to!string;
        }
    }

    string toString() const {
        if (_payload is null) {
            return "null";
        }
        static if (__traits(compiles, _payload.toString())) {
            return _payload.toString();
        } else {
            auto obj = cast(Object) _payload;
            return obj !is null ? obj.toString() : "null";
        }
    }

    /// Wrap an existing `T` (or `null`).
    static RefCounted!T opCall(U)(U payload)
        if (!isRefCounted!U && (is(U : T) || is(U == typeof(null))))
    {
        if (payload is null) {
            return RefCounted!T.init;
        }
        return fromParts(payload, new size_t(1));
    }

    /// Copy or upcast from another `RefCounted!U` where `U : T`, sharing the reference count.
    static RefCounted!T opCall(U)(auto ref RefCounted!U other)
        if (is(U : T))
    {
        if (other._refCount !is null) {
            ++(*other._refCount);
        }
        return fromParts(other._payload, other._refCount);
    }

    /// Directly construct a concrete class `T` using any of `T`'s constructors.
    static if (is(T == class) && !__traits(isAbstractClass, T)) {
        static RefCounted!T opCall(Args...)(auto ref Args args)
            if (!(Args.length == 1 && (
                    is(Args[0] == typeof(null))
                    || is(Args[0] : T)
                    || (is(Unqual!(Args[0]) == RefCounted!U, U) && is(U : T))
                ))
                && __traits(compiles, new T(forward!args)))
        {
            return fromParts(new T(forward!args), new size_t(1));
        }
    }

    this(this) {
        if (_refCount !is null) {
            ++(*_refCount);
        }
    }

    ~this() {
        _release();
    }

    ref RefCounted!T opAssign(RefCounted!T rhs) {
        swap(_payload, rhs._payload);
        swap(_refCount, rhs._refCount);
        return this;
    }

    ref RefCounted!T opAssign(U)(RefCounted!U rhs)
        if (!is(U == T) && is(U : T))
    {
        auto old = fromParts(_payload, _refCount);
        _payload = rhs._payload;
        _refCount = rhs._refCount;
        rhs._payload = null;
        rhs._refCount = null;
        return this;
    }

    ref RefCounted!T opAssign(typeof(null)) {
        _release();
        return this;
    }
}

/// Convenience factory that wraps an existing `IDisposable` class or interface instance,
/// inferring `T` automatically.
RefCounted!T refCounted(T)(T payload)
    if ((is(T == class) || is(T == interface)) && is(T : IDisposable))
{
    return RefCounted!T(payload);
}

/// Explicitly constructs a new `T` instance with `args` wrapped in a `RefCounted!T`
/// (analogous to C++ `std::make_shared`).
RefCounted!T makeRefCounted(T, Args...)(auto ref Args args)
    if (is(T == class) && !__traits(isAbstractClass, T) && is(T : IDisposable)
        && __traits(compiles, new T(forward!args)))
{
    return RefCounted!T(new T(forward!args));
}
