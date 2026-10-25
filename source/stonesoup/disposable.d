module stonesoup.disposable;

interface IDisposable {
    void dispose();
}

// thanks to Paul Backus:
struct Disposable(T : IDisposable)
{
    T unwrap;
    alias unwrap this;
    ~this()
    {
        if (unwrap !is null) {
            unwrap.dispose();
            unwrap = null; // so that GC.collect() works a bit more deterministically for testing (maybe)
        }
    }
}

Disposable!T using(T : IDisposable)(T payload)
{
    return Disposable!T(payload);
}

// for use with the 'dispose pattern'
// (instead of the usual `bool disposing` parameter used by convention with C#)
enum DisposeSource {
    DisposeMethod,
    Finalizer
}
