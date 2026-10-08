module stonesoup.result;

// !sumgen
enum ResultDef = q{
Result(T,E) {
    Success(T),
    Error(E)
}};

auto map(alias fun, T, E)(Result!(T,E) result) {
    alias U = typeof(fun(T.init));
    if (auto succ = result.isSuccess()) {
        auto value = fun(*succ);
        return Result!(U,E).Success(value);
    } else if (auto err = result.isError()) {
        return Result!(U,E).Error(*err);
    }
    // unreachable
    assert(0);
}

auto mapError(alias fun, T, E)(Result!(T,E) result) {
    alias E2 = typeof(fun(E.init));
    if (auto succ = result.isSuccess()) {
        return Result!(T,E2).Success(*succ);
    } else if (auto err = result.isError()) {
        auto value = fun(*err);
        return Result!(T,E2).Error(value);
    }
    // unreachable
    assert(0);
}

// == sumgen v0.5 ==============================================================
// ===== GENERATED CODE BELOW - ANYTHING ADDED BELOW WILL BE DESTROYED!! =======
// =============================================================================

struct Result(T, E) {
    import std.exception: enforce;
private:
    // Success: name + single type, no fields
    // Error: name + single type, no fields

    union Content {
        T success;
        E error;
    }
    Tag _tag;
    Content content;
public:
    enum Tag { Success, Error }
    Tag tag() => _tag;

    // Success ==================================
    static Result Success(T value) {
        Content c = { success: value };
        return Result(Tag.Success, c);
    }
    T* isSuccess() => _tag == Tag.Success ? &content.success : null;
    ref T getSuccess() {
        enforce(_tag == Tag.Success, "Result.getSuccess(): tag doesn't match");
        return content.success;
    }

    // Error ==================================
    static Result Error(E value) {
        Content c = { error: value };
        return Result(Tag.Error, c);
    }
    E* isError() => _tag == Tag.Error ? &content.error : null;
    ref E getError() {
        enforce(_tag == Tag.Error, "Result.getError(): tag doesn't match");
        return content.error;
    }

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
            case Tag.Success:
                return inputCases.canFind("Success");
            case Tag.Error:
                return inputCases.canFind("Error");
        }
    }

    // exhaustive check =======================
    // place in a static assert so you can catch all the places that need to be changed, when you add a new case
    static bool isExhaustive(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(", ").sort();
        auto checkAgainst = ["Success", "Error"].sort();
        return inputCases == checkAgainst;
    }

    // basic match expression =====================
    struct _NameOnly {}
    _MatchResult match(_MatchResult)(
        _MatchResult delegate(ref T) successFunc,
        _MatchResult delegate(ref E) errorFunc)
    {
        _NameOnly fakeArg;
        final switch(_tag) {
            case Tag.Success:
                return successFunc(content.success);
            case Tag.Error:
                return errorFunc(content.error);
        }
    }

    // visitor-style match expression =============
    abstract class Matcher(_MatchResult) {
        _MatchResult success(T value) => _any();
        _MatchResult error(E value) => _any();
        _MatchResult _any() {
            throw new Exception("Result.Matcher._any() called, but not implemented");
        }
    }

    _MatchResult match(_MatchResult)(Matcher!_MatchResult matcher) {
        final switch(_tag) {
            case Tag.Success:
                return matcher.success(content.success);
            case Tag.Error:
                return matcher.error(content.error);
        }
    }
}

// =============================================================================
// ========= DO NOT ADD CODE BELOW (or above) - IT WILL BE DESTROYED !! ========
// =============================================================================
