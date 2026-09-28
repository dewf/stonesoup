module stonesoup.sumtype;

import stonesoup.sumtype.parser;

import std.array : appender, join;
import std.ascii: toUpper, toLower;
import std.algorithm: map;
import std.format;

string upperFirst(string s) {
	if (!s || s.length == 0) return s;
	return toUpper(s[0]) ~ s[1 .. $];
}

string lowerFirst(string s) {
	if (!s || s.length == 0) return s;
	return toLower(s[0]) ~ s[1 .. $];
}

string sumtype(string input) {
	auto maybeSumType = parseSumType(input);
	if (maybeSumType.isNull) return "static assert(0, \"sumtype: bad format\")";
	auto def = maybeSumType.get();

	auto output = appender!string;

	if (def.typeParams.length > 0) {
		auto joined = def.typeParams.join(", ");
		output ~= format("struct %s(%s) {\n", def.name.upperFirst(), joined);
	} else {
		output ~= format("struct %s {\n", def.name.upperFirst());
	}

	output ~= "    import std.exception: enforce;\n";
	output ~= "private:\n";

	output ~= "    union Content {\n";
	foreach (c; def.cases) {
		auto caseUpper = c.name.upperFirst();
		auto caseLower = c.name.lowerFirst();
		output ~= format("        %s %s;\n", caseUpper, caseLower);
	}
	output ~= "    }\n"; // end union Content

	output ~= "    Tag _tag;\n";
	output ~= "    Content content;\n";
	output ~= "public:\n";

	auto tagNames = def.cases.map!(c => c.name.upperFirst()).join(", ");
	output ~= format("    enum Tag { %s }\n", tagNames);

	output ~= "    Tag tag() => _tag;\n";
	output ~= "    enum TagAny = cast(Tag) 1024;\n";

	output ~= "\n";

	// struct defs
	foreach (c; def.cases) {
		auto caseUpper = c.name.upperFirst();

		if (c.params.length > 0) {
			auto fields = c.params.map!(p => format("%s %s;", p.type, p.name)).join(" ");
			output ~= format("    struct %s { %s }\n", caseUpper, fields);
		} else {
			output ~= format("    struct %s {}\n", caseUpper);
		}
	}

	// output ~= "\n";

	// ctor/getters
	foreach (c; def.cases) {
		auto caseUpper = c.name.upperFirst();
		auto caseLower = c.name.lowerFirst();

		// if (i != 0) output ~= "\n";
		output ~= "\n";

		output ~= format("    // %s ==================================\n", caseUpper);
		// ctor
		auto ctorParams = c.params.map!(p => format("%s %s", p.type, p.name)).join(", ");
		output ~= format("    static %s mk%s(%s) {\n", def.name.upperFirst(), caseUpper, ctorParams);
		auto fieldNames = c.params.map!(p => p.name).join(", ");
		output ~= format("        Content c = { %s: %s(%s) };\n", caseLower, caseUpper, fieldNames);
		output ~= format("        return %s(Tag.%s, c);\n", def.name.upperFirst(), caseUpper);
		output ~= "    }\n";
		// "is" checker+getter
		output ~= format("    const (%s)* is%s() => _tag == Tag.%s ? &content.%s : null;\n", caseUpper, caseUpper, caseUpper, caseLower);
		// force-getter
		output ~= format("    ref const(%s) %s() {\n", caseUpper, caseLower);
		output ~= format("        enforce(_tag == Tag.%s, \"%s.%s(): tag doesn't match\");\n", caseUpper, def.name.upperFirst(), caseLower);
		output ~= format("        return content.%s;\n", caseLower);
		output ~= "    }\n";
	}

	// multi-test
	output ~= "\n";
	output ~= "    // multi-test ==========================\n";
	output ~= q"EOF
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
EOF";
	foreach (c; def.cases) {
		auto caseUpper = c.name.upperFirst();
		output ~= format("            case Tag.%s:\n", caseUpper);
		output ~= format("                return inputCases.canFind(\"%s\");\n", caseUpper);
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end isOneOf()

	// exhaustive check
	output ~= "\n";
	output ~= q"EOF
    // exhaustive check =======================
    // place in a static assert so you can catch all the places that need to be changed, when you add a new case
    static bool isExhaustive(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(", ").sort();
EOF";
	auto caseNames = def.cases.map!(c => format("\"%s\"", c.name.upperFirst())).join(", ");
	output ~= format("        auto checkAgainst = [%s].sort();\n", caseNames);
	output ~= "        return inputCases == checkAgainst;\n";
	output ~= "    }\n"; // end isExhaustive

	// basic match expression
	output ~= "\n";
	output ~= "    // basic match expression =====================\n";
	output ~= "    _MatchResult match(_MatchResult)(\n";
	auto delegateArgs = def.cases.map!(c => format("        _MatchResult delegate(%s) %sFunc", c.name.upperFirst(), c.name.lowerFirst())).join(",\n");
	output ~= format("%s)\n", delegateArgs);
	output ~= "    {\n";
	output ~= "        final switch(_tag) {\n";
	foreach (c; def.cases) {
		output ~= format("            case Tag.%s:\n", c.name.upperFirst());
		output ~= format("                return %sFunc(content.%s);\n", c.name.lowerFirst(), c.name.lowerFirst());
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end basic match expression

	// associative array style match
	output ~= "\n";
	output ~= q"EOF
    alias ReturnDelegate(_MatchResult) = _MatchResult delegate();
    alias MatchExpr(_MatchResult) = ReturnDelegate!_MatchResult[Tag]; // unfortunately needed for casting :(
    _MatchResult match(_MatchResult)(ReturnDelegate!_MatchResult[Tag] delegateMap) {
        if (auto found = _tag in delegateMap) {
            return (*found)();
        } else if (auto found = TagAny in delegateMap) {
            return (*found)();
        } else {
EOF";
	output ~= format("            throw new Exception(\"%s.match() - unhandled tag(%%s)\", _tag.stringof);\n", def.name.upperFirst());
	output ~= "        }\n"; // end else
	output ~= "    }\n"; // end AA style match

	// visitor-style match expression
	output ~= "\n";
	output ~= "    // visitor-style match expression =============\n";
	output ~= "    abstract class Matcher(_MatchResult) {\n";
	foreach (c; def.cases) {
		auto args = c.params.map!(p => format("%s %s", p.type, p.name)).join(", ");
		output ~= format("        _MatchResult %s(%s) => any();\n", c.name.lowerFirst(), args);
	}
	output ~= "        _MatchResult any() {\n";
	output ~= format("            assert(0, \"%s.Matcher.any() called, but not implemented\");\n", def.name.upperFirst());
	output ~= "        }\n";
	output ~= "        // convenience method to reduce a little bit of typing:\n";
	output ~= format("        _MatchResult match(%s thing) {\n", def.name.upperFirst);
	output ~= "            return thing.match(this);\n";
	output ~= "        }\n";
	output ~= "    }\n";

	// visit method
	output ~= "\n";
	output ~= "    _MatchResult match(_MatchResult)(Matcher!_MatchResult matcher) {\n";
	output ~= "        final switch(_tag) {\n";
	foreach (c; def.cases) {
		output ~= format("            case Tag.%s:\n", c.name.upperFirst());
		auto args = c.params.map!(p => format("content.%s.%s", c.name.lowerFirst(), p.name)).join(", ");
		output ~= format("                return matcher.%s(%s);\n", c.name.lowerFirst(), args);
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end match()

	output ~= "}\n"; // end struct!

	return output[];
}
