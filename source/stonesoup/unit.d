module stonesoup.unit;

struct Unit {
    bool opEquals(const Unit) const => true;
    size_t toHash() const => 0;
}
