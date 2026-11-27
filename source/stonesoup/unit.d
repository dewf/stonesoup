module stonesoup.unit;

struct Unit {
    bool opEquals(const Unit) const pure nothrow @safe @nogc => true;
    size_t toHash() const pure nothrow @safe @nogc => 0;
}
