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

// // 1. The custom 'using' struct
// struct UsingBlock(T : IDisposable) {
//     T resource;
//     // opApply defines what happens when this struct is put in a foreach loop
//     int opApply(int delegate(ref T) dg) {
//         // Guarantee cleanup when the delegate (the block) finishes
//         scope(exit) {
//             resource.dispose();
//         }
//         // Execute the block of code, passing the resource to it
//         return dg(resource);
//     }
// }
// // Helper function so we don't have to explicitly type UsingBlock!(MyClass)
// auto using(T)(T resource) {
//     return UsingBlock!T(resource);
// }
