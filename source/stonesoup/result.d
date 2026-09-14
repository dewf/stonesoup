module stonesoup.result;

struct Result(T, Err) {
private:
    union Payload {
        T value;
        Err error;
    }
    Payload payload;
    bool _isSuccess;
public:
    bool isSuccess() => _isSuccess;

    T value() {
        if (isSuccess) {
            return payload.value;
        } // else:
        throw new Error("Result type: tried to access .value() while in error state");
    }

    Err error() {
        if (!isSuccess) {
            return payload.error;
        } // else:
        throw new Error("Result type: tried to access .error() while in success state");
    }

    static Result!(T, Err) ok(T value) {
        Result!(T, Err) res;
        res._isSuccess = true;
        res.payload.value = value;
        return res;
    }

    static Result!(T, Err) err(Err e) {
        Result!(T, Err) res;
        res._isSuccess = false;
        res.payload.error = e;
        return res;
    }
}
