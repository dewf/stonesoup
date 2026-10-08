module stonesoup.option;

// !sumgen
enum OptionDef = q{
Option(T) {
    Some(T),
    None
}};

// Option!U map(T,U)(Option!T opt, U delegate(T) func) {
//     if (auto some = opt.isSome()) {
//         return Option!U.Some(func(*some));
//     }
//     return Option!U.None();
// }

// the only way to infer types :(
auto map(alias fun, T)(Option!T opt)
{
    alias U = typeof(fun(T.init));
    if (auto some = opt.isSome()) {
        return Option!U.Some(fun(*some));
    }
    return Option!U.None();
}

T getOrDefault(T)(Option!T opt, T defaultValue) {
    if (auto some = opt.isSome()) {
        return *some;
    }
    return defaultValue;
}

Option!T flatten(T)(Option!(Option!T) optopt) {
    if (auto opt = optopt.isSome()) {
        return *opt;
    }
    return Option!T.None();
}

// == sumgen v0.5 ==============================================================
// ===== GENERATED CODE BELOW - ANYTHING ADDED BELOW WILL BE DESTROYED!! =======
// =============================================================================

struct Option(T) {
    import std.exception: enforce;
private:
    // Some: name + single type, no fields
    // None: name only

    union Content {
        T some;
        // none: name only
    }
    Tag _tag;
    Content content;
public:
    enum Tag { Some, None }
    Tag tag() => _tag;

    // Some ==================================
    static Option Some(T value) {
        Content c = { some: value };
        return Option(Tag.Some, c);
    }
    T* isSome() => _tag == Tag.Some ? &content.some : null;
    ref T getSome() {
        enforce(_tag == Tag.Some, "Option.getSome(): tag doesn't match");
        return content.some;
    }

    // None ==================================
    static Option None() {
        Content c;
        return Option(Tag.None, c);
    }
    bool isNone() => _tag == Tag.None;
    // name-only, no getter

    // multi-test ==========================
    bool isOneOf(Tag[] tags ...) {
        foreach (t; tags) {
            if (t == _tag) return true;
        }
        return false;
    }
    bool isOneOf(string caseNames)() {
        import std.string: split;
        import std.algorithm : canFind;
        static immutable inputCases = caseNames.split(", ");
        static assert(inputCases.length > 0, "isOneOf: no case names provided");
        final switch (_tag) {
            case Tag.Some:
                return inputCases.canFind("Some");
            case Tag.None:
                return inputCases.canFind("None");
        }
    }

    // exhaustive check =======================
    // place in a static assert so you can catch all the places that need to be changed, when you add a new case
    static bool isExhaustive(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(", ").sort();
        auto checkAgainst = ["Some", "None"].sort();
        return inputCases == checkAgainst;
    }

    // basic match expression =====================
    struct _NameOnly {}
    _MatchResult match(_MatchResult)(
        _MatchResult delegate(ref T) someFunc,
        _MatchResult delegate(ref _NameOnly) noneFunc)
    {
        _NameOnly fakeArg;
        final switch(_tag) {
            case Tag.Some:
                return someFunc(content.some);
            case Tag.None:
                return noneFunc(fakeArg);
        }
    }

    // visitor-style match expression =============
    abstract class Matcher(_MatchResult) {
        _MatchResult some(T value) => _any();
        _MatchResult none() => _any();
        _MatchResult _any() {
            throw new Exception("Option.Matcher._any() called, but not implemented");
        }
    }

    _MatchResult match(_MatchResult)(Matcher!_MatchResult matcher) {
        final switch(_tag) {
            case Tag.Some:
                return matcher.some(content.some);
            case Tag.None:
                return matcher.none();
        }
    }
}

// =============================================================================
// ========= DO NOT ADD CODE BELOW (or above) - IT WILL BE DESTROYED !! ========
// =============================================================================
