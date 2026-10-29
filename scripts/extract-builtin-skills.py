#!/usr/bin/env python3
"""Extract the prompts of Claude Code's built-in skills from an installed binary.

Usage: python3 -I scripts/extract-builtin-skills.py BINARY OUTDIR SKILL...

Writes OUTDIR/<skill>.md for each named skill. A skill the extractor cannot
find, whether Claude Code dropped it or changed how it is registered, writes no
file: the others are written, then the run exits non-zero naming the missing
ones (a real removal is a hand edit of the skills list). A skill registered but
yielding no prompt text, and any other failure (missing binary, unparseable
bundle, undecodable module), raises.

The Linux binary is a Bun standalone executable: a module graph (the app's JS
chunks plus embedded files, some zstd-compressed) sits in the .bun section,
located through a trailer at the end of that section. A module is decoded by
the encoding byte of its record (1 latin-1, 2 UTF-16LE; .zst is decompressed,
then UTF-8), strictly. Two kinds of skill:

* Embedded markdown skills ship as SKILL-*.md files. They are found by the
  `name:` in their frontmatter, or through a registration that loads a bundled
  SKILL_MD (the loader module is followed to the file). The supporting files
  of the loader's SKILL_FILES map are appended. The text is verbatim.
* Inline skills have their prompt in the JS as string/template literals. The
  skill is found by its registration, a `fn({name:<literal or constant>,...})`
  call. The prompt is the set of "prompt-bearing" units (a top-level function,
  or one declarator of a `var`, holding a literal of PROMPT_MIN chars or more)
  reachable from that registration by following identifier references: into a
  unit that is mostly literal wherever it lives (this chunk, or an imported
  chunk smaller than CROSS_CHUNK_MAX), or into any unit of the same chunk
  within NEAR bytes; at most NON_PROMPT_HOPS units without a long literal may
  sit between two prompt-bearing ones. Each prompt-bearing unit contributes its
  literals of LITERAL_MIN chars or more, in source order, escapes decoded.
  Minified identifiers never reach the output: an interpolation that is a
  string or number constant is replaced by its value, any other becomes
  `${...}` with its identifiers replaced by `_`, so a release that only renames
  identifiers produces the same text.

Requires the zstd command-line tool (the standard library has no zstd before
Python 3.14).
"""
import bisect
import mmap
import os
import re
import struct
import subprocess
import sys

TRAILER = b"\n---- Bun! ----\n"
MODULE_SIZE = 52          # bytes per module record in the Bun module table
ENCODING_OFFSET = 48      # the record's encoding byte: 0 binary, 1 latin-1, 2 UTF-16LE
TEXT_CODECS = {1: "latin-1", 2: "utf-16-le"}
PROMPT_MIN = 80           # a unit with a literal this long is prompt-bearing
LITERAL_MIN = 30          # shortest literal worth emitting
NON_PROMPT_HOPS = 2       # non-prompt-bearing units allowed in a row between prompt-bearing ones
NEAR = 60_000             # a unit that is not mostly literal is followed only within its chunk and this close
CROSS_CHUNK_MAX = 400_000  # imports are followed only into chunks smaller than this
CONST_MAX = 60            # longest string constant inlined into an interpolation

INLINE_HEADER = (
    "<!-- Claude Code built-in skill `{}`, extracted from the binary: the string and template "
    "literals of its prompt code in source order, escapes decoded. In `${{...}}` interpolations "
    "minified identifiers are shown as `_`. -->\n"
)


# --- Bun bundle ---------------------------------------------------------

class Bundle:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        ti = self.m.rfind(TRAILER)
        if ti < 32:
            raise RuntimeError(f"{path}: no Bun trailer, not a Bun standalone executable")
        # Offsets struct before the trailer: byte_count u64, modules {off u32, len u32}, ...
        byte_count, = struct.unpack_from("<Q", self.m, ti - 32)
        mod_off, mod_len = struct.unpack_from("<II", self.m, ti - 24)
        base = ti - 32 - byte_count
        if mod_len % MODULE_SIZE:
            raise RuntimeError(f"{path}: module table length {mod_len} is not a multiple of {MODULE_SIZE}")
        self.mods = {}  # name -> (offset, length, encoding byte)
        for i in range(mod_len // MODULE_SIZE):
            record = base + mod_off + i * MODULE_SIZE
            name_off, name_len, off, length = struct.unpack_from("<IIII", self.m, record)
            name = self.m[base + name_off:base + name_off + name_len].decode()
            self.mods[name] = (base + off, length, self.m[record + ENCODING_OFFSET])
        if not self.mods or not all(n.startswith("/$bunfs/") for n in self.mods):
            raise RuntimeError(f"{path}: module table does not look like a Bun module graph")
        self.texts = {}
        self.chunks = {}

    def is_chunk(self, name):
        """A JS chunk we can read as text (a few .js modules are zstd-compressed binaries)."""
        return name.endswith(".js") and self.mods[name][2] in TEXT_CODECS

    def contains(self, name, needle):
        """Whether the ASCII string `needle` occurs in the stored bytes of the text module `name`."""
        off, length, encoding = self.mods[name]
        return self.m.find(needle.encode(TEXT_CODECS[encoding]), off, off + length) >= 0

    def text(self, name):
        if name not in self.texts:
            off, length, encoding = self.mods[name]
            data = self.m[off:off + length]
            if name.endswith(".zst"):
                data = subprocess.run(["zstd", "-dc"], input=data, capture_output=True, check=True).stdout
                codec = "utf-8"
            elif encoding in TEXT_CODECS:
                codec = TEXT_CODECS[encoding]
            else:
                raise RuntimeError(f"{name}: module encoding {encoding} is not text")
            self.texts[name] = data.decode(codec)
        return self.texts[name]

    def chunk(self, name):
        if name not in self.chunks:
            self.chunks[name] = Chunk(self, name)
        return self.chunks[name]


# --- JS lexer -----------------------------------------------------------
# Enough of JavaScript to cut minified bundler output into top-level statements:
# strings, template literals with nested expressions, regex literals, comments.

TOK = re.compile(r"[A-Za-z_$][\w$]*|[0-9][\w.]*|\.\.\.|\"|'|`|/\*|//|\s+|.", re.S)
REGEX_AFTER_WORD = {"return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw", "case", "do", "else", "yield", "await"}


def skip_str(s, i, q):
    while True:
        c = s[i]
        if c == "\\":
            i += 2
        elif c == q:
            return i + 1
        else:
            i += 1


def skip_tpl(s, i, exprs=None):
    """i is just past the opening backtick; return the index past the closing one.
    Appends the (start, end) span of each ${...} body to exprs."""
    while True:
        c = s[i]
        if c == "\\":
            i += 2
        elif c == "`":
            return i + 1
        elif c == "$" and s[i + 1] == "{":
            j = skip_expr(s, i + 2)
            if exprs is not None:
                exprs.append((i + 2, j - 1))
            i = j
        else:
            i += 1


def skip_expr(s, i):
    depth = 1
    for kind, a, b in tokens(s, i, len(s)):
        if kind == "p":
            if s[a] == "{":
                depth += 1
            elif s[a] == "}":
                depth -= 1
                if depth == 0:
                    return b
    raise ValueError("unterminated ${ expression")


def tokens(s, i, end):
    """Yield (kind, start, end), kind in id, num, str, tpl, re, dot (property access), p. Skips whitespace and comments."""
    prev = None
    while i < end:
        m = TOK.match(s, i)
        assert m, "TOK ends in `.`, which matches any character"
        t = m.group(0)
        a = i
        i += len(t)
        c = t[0]
        if c.isspace():
            continue
        if t == "//":
            j = s.find("\n", a)
            i = end if j < 0 else j
            continue
        if t == "/*":
            i = s.index("*/", a + 2) + 2
            continue
        if c in "\"'":
            i = skip_str(s, i, c)
            yield ("str", a, i)
            prev = ("v", "")
            continue
        if c == "`":
            i = skip_tpl(s, i)
            yield ("tpl", a, i)
            prev = ("v", "")
            continue
        if c == "/":
            after_value = prev is not None and (prev[0] in ("v", "num") or (prev[0] == "id" and prev[1] not in REGEX_AFTER_WORD) or (prev[0] == "p" and prev[1] in ")]}"))
            if not after_value:
                j = a + 1
                in_class = False
                while True:
                    d = s[j]
                    if d == "\\":
                        j += 2
                        continue
                    if d == "[":
                        in_class = True
                    elif d == "]":
                        in_class = False
                    elif d == "/" and not in_class:
                        break
                    j += 1
                j += 1
                while j < end and (s[j].isalnum() or s[j] in "_$"):
                    j += 1
                i = j
                yield ("re", a, i)
                prev = ("v", "")
                continue
        if c.isalpha() or c in "_$":
            yield ("id", a, i)
            prev = ("id", t)
        elif c.isdigit():
            yield ("num", a, i)
            prev = ("num", t)
        elif t == ".":
            yield ("dot", a, i)
            prev = ("p", ".")
        else:
            yield ("p", a, i)
            prev = ("p", t)


class Decl:
    """Top-level declaration: index of its unit and, for `var x=init`, the span of the init."""
    def __init__(self, unit, init=None):
        self.unit = unit
        self.init: tuple[int, int] | None = init


def split_units(s):
    """Cut top-level code into units: a function/class/expression statement, or one declarator of a
    var/let/const statement. Returns (units, decls): units is [(start, end)], decls maps a declared name to a Decl."""
    units = []
    decls = {}
    depth = 0
    start = None
    toks = []        # first three tokens of the current statement
    count = 0        # tokens seen in the current statement
    split = False    # the current statement was cut into declarator units
    state = None     # var/let/const declarator tracking: name, eq, init
    pending = name_start = init_start = None

    def end_statement(end):
        nonlocal start
        if not split:
            units.append((start, end))
        start = None

    for kind, a, b in tokens(s, 0, len(s)):
        if start is None:
            start, toks, count, split, state = a, [], 0, False, None
        count += 1
        if count <= 3:
            toks.append((kind, s[a:b]))
        first = toks[0][1]
        if count == 1 and kind == "id" and first in ("var", "let", "const"):
            state = "name"
            continue
        if kind == "id" and ((count == 2 and first in ("function", "class")) or (count == 3 and first == "async" and toks[1][1] == "function")):
            decls[s[a:b]] = Decl(len(units))
        if depth == 0 and state == "name":
            if kind == "id":
                pending, name_start, state = s[a:b], a, "eq"
                continue
            state = None
        elif depth == 0 and state == "eq":
            if kind == "p" and s[a] == "=":
                state, init_start = "init", None
                continue
            state = "name" if kind == "p" and s[a] == "," else None
        elif depth == 0 and state == "init" and init_start is None:
            init_start = a
        if kind != "p":
            continue
        c = s[a]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            ends_on_brace = first in ("function", "class", "export") or (first == "async" and toks[1][1] == "function")
            if depth == 0 and c == "}" and ends_on_brace:
                end_statement(b)
        elif depth == 0 and c in ",;":
            if state == "init":
                decls[pending] = Decl(len(units), (init_start, a))
                units.append((name_start, a))
                split = True
                state = "name" if c == "," else None
            if c == ";":
                end_statement(b)
    if start is not None:
        end_statement(len(s))
    return units, decls


# --- Chunks: units, imports, exports, references -------------------

# A skill registration: fn({name:"literal",...}) or fn({name:CONSTANT,...})
REGISTRATION = re.compile(r'[\w$]\(\{name:("(?:[^"\\]|\\.)*"|[\w$]+),')
IMPORT_RE = re.compile(r'import(?:\{([^}]*)\}from)?"([^"]+)";?')
EXPORT_RE = re.compile(r"export\{([^}]*)\}")


def specifiers(text):
    """Parse `a,b as c` into [(source_name, bound_name)]."""
    out = []
    for item in text.split(","):
        parts = item.split(" as ")
        if parts[0].strip():
            out.append((parts[0].strip(), parts[-1].strip()))
    return out


class Chunk:
    def __init__(self, bundle, name):
        self.bundle = bundle
        self.name = name
        self.s = bundle.text(name)
        self.imports = {}   # local name -> (module name, exported name)
        pos = self.s.find("\nimport") + 1
        while pos > 0:
            m = IMPORT_RE.match(self.s, pos)
            if not m:
                break
            for exported, local in specifiers(m.group(1) or ""):
                self.imports[local] = (m.group(2), exported)
            pos = m.end()
            while self.s[pos].isspace():
                pos += 1
        self.exports = {}   # exported name -> local name
        e = self.s.rfind("export{")
        if e >= 0:
            m = EXPORT_RE.match(self.s, e)
            if m:
                for local, exported in specifiers(m.group(1)):
                    self.exports[exported] = local
        self.registrations = [(m.start(), m.group(1)) for m in REGISTRATION.finditer(self.s)]
        self._parsed = None
        self._refs = {}
        self._longest = {}

    def parse(self):
        if self._parsed is None:
            self._parsed = split_units(self.s)
        return self._parsed

    @property
    def units(self):
        return self.parse()[0]

    @property
    def decls(self):
        return self.parse()[1]

    def init_span(self, ident):
        d = self.decls.get(ident)
        if not d or not d.init:
            raise RuntimeError(f"{self.name}: `{ident}` is not declared with an initialiser")
        return d.init

    def unit_at(self, pos):
        return bisect.bisect_right([a for a, _ in self.units], pos) - 1

    def refs(self, i):
        """Identifiers referenced in unit i (not property names), first-occurrence order."""
        if i not in self._refs:
            a, b = self.units[i]
            self._refs[i] = list(dict.fromkeys(identifiers(self.s, a, b)))
        return self._refs[i]

    def longest_literal(self, i):
        if i not in self._longest:
            a, b = self.units[i]
            self._longest[i] = max([y - x for k, x, y in tokens(self.s, a, b) if k in ("str", "tpl")], default=0)
        return self._longest[i]

    def prompt_bearing(self, i):
        return self.longest_literal(i) >= PROMPT_MIN

    def prompt_dense(self, i):
        a, b = self.units[i]
        return self.longest_literal(i) >= PROMPT_MIN and self.longest_literal(i) * 2 >= b - a


def identifiers(s, a, b):
    """Identifier tokens in s[a:b] that can refer to a variable: not property names, not object keys."""
    out = []
    toks = list(tokens(s, a, b))
    for k, (kind, x, y) in enumerate(toks):
        if kind == "id":
            before = toks[k - 1] if k else None
            after = toks[k + 1] if k + 1 < len(toks) else None
            is_key = after and after[0] == "p" and s[after[1]] == ":" and before and before[0] == "p" and s[before[1]] in "{,"
            if not (before and before[0] == "dot") and not is_key:
                out.append(s[x:y])
        elif kind == "tpl":
            exprs = []
            skip_tpl(s, x + 1, exprs)
            for p, q in exprs:
                out.extend(identifiers(s, p, q))
    return out


def lookup(bundle, chunk, ident, depth=0):
    """Resolve an identifier used in chunk to (defining chunk, Decl), following imports and re-exports."""
    if depth > 8:
        return None
    if ident in chunk.imports:
        module, exported = chunk.imports[ident]
        if module not in bundle.mods or bundle.mods[module][1] > CROSS_CHUNK_MAX:
            return None
        target = bundle.chunk(module)
        local = target.exports.get(exported)
        return lookup(bundle, target, local, depth + 1) if local else None
    d = chunk.decls.get(ident)
    return (chunk, d) if d else None


ESCAPE = re.compile(r"\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|\r?\n|.)", re.S)
SIMPLE_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f", "v": "\v", "0": "\0"}


def cook(raw):
    def one(m: re.Match[str]) -> str:
        g = m.group(1)
        if g[0] == "u" and len(g) > 1:
            return chr(int(g[2:-1] if g[1] == "{" else g[1:], 16))
        if g[0] == "x" and len(g) == 3:
            return chr(int(g[1:], 16))
        if g in ("\n", "\r\n"):
            return ""
        return SIMPLE_ESCAPES.get(g, g)
    out = ESCAPE.sub(one, raw)
    return out.encode("utf-16-le", "surrogatepass").decode("utf-16-le", "replace")  # re-pair \ud83d\ude00 style escapes


def constant_value(bundle, chunk, ident):
    """Text of a top-level `ident="..."`, a template without interpolation, or a number; else None."""
    hit = lookup(bundle, chunk, ident)
    if not hit or not hit[1].init:
        return None
    c, d = hit
    toks = list(tokens(c.s, *d.init))
    if len(toks) != 1:
        return None
    kind, a, b = toks[0]
    if kind == "num":
        return c.s[a:b]
    if kind not in ("str", "tpl") or (kind == "tpl" and "${" in c.s[a:b]):
        return None
    return cook(c.s[a + 1:b - 1])


KEEP = {"true", "false", "null", "undefined", "void", "typeof", "new", "this", "return", "await", "async", "function", "if", "else", "in", "of", "instanceof", "delete",
        "Math", "JSON", "Object", "Array", "String", "Number", "Boolean", "Set", "Map", "Date", "Promise", "RegExp", "Symbol", "Error", "process", "Infinity", "NaN", "let", "const", "var"}


def normalize_expr(bundle, chunk, a, b):
    """Source of chunk.s[a:b] with minified identifiers replaced by `_`; string and template
    literals inside it are decoded like top-level ones (constants inlined, nested expressions normalised)."""
    s = chunk.s
    out = []
    pos = a
    after_dot = False
    for kind, x, y in tokens(s, a, b):
        out.append(s[pos:x])
        if kind == "id":
            out.append(s[x:y] if after_dot or s[x:y] in KEEP else "_")
        elif kind == "str":
            out.append(s[x] + cook(s[x + 1:y - 1]) + s[x])
        elif kind == "tpl":
            out.append("`" + render_template(bundle, chunk, x, y) + "`")
        else:
            out.append(s[x:y])
        pos = y
        after_dot = kind == "dot"
    out.append(s[pos:b])
    return "".join(out)


def interpolation(bundle, chunk, p, q):
    """Text standing for the ${...} body chunk.s[p:q]: a string literal or short constant inline, else the normalised expression."""
    toks = list(tokens(chunk.s, p, q))
    if len(toks) == 1:
        kind, x, y = toks[0]
        if kind == "str":
            return cook(chunk.s[x + 1:y - 1])
        if kind == "id":
            value = constant_value(bundle, chunk, chunk.s[x:y])
            if value is not None and len(value) <= CONST_MAX and "\n" not in value:
                return value
    return "${" + normalize_expr(bundle, chunk, p, q) + "}"


def render_template(bundle, chunk, a, b):
    """Cooked text of the template literal chunk.s[a:b] (backticks included)."""
    s = chunk.s
    exprs = []
    skip_tpl(s, a + 1, exprs)
    out = []
    pos = a + 1
    for p, q in exprs:
        out.append(cook(s[pos:p - 2]))
        out.append(interpolation(bundle, chunk, p, q))
        pos = q + 1
    out.append(cook(s[pos:b - 1]))
    return "".join(out)


# --- Embedded markdown skills -------------------------------------------

def frontmatter_name(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    m = re.search(r"^name:[ \t]*(.+?)[ \t]*$", text[4:end] if end > 0 else "", re.M)
    return m.group(1).strip("'\"") if m else None


def loaded_file(bundle, chunk, a, b, depth=0):
    """Module name of the embedded file loaded by the expression chunk.s[a:b]: a string path, an alias
    of one, or a call on one. A path ending in .js is a wrapper module exporting the file as `default`."""
    s = chunk.s
    for kind, x, y in tokens(s, a, b):
        if kind == "str" and s.startswith("/$bunfs/", x + 1):
            path = s[x + 1:y - 1]
            if not path.endswith(".js"):
                return path
            wrapper = bundle.chunk(path)
            return loaded_file(bundle, wrapper, *wrapper.init_span(wrapper.exports["default"]), depth=depth + 1)
    if depth < 8:
        for ident in reversed(identifiers(s, a, b)):
            d = chunk.decls.get(ident)
            if d and d.init:
                return loaded_file(bundle, chunk, *d.init, depth=depth + 1)
    raise RuntimeError(f"{chunk.name}: cannot tell which embedded file `{s[a:b]}` loads")


def object_entries(s, a, b):
    """[(key, value start, value end)] for the entries of the object literal s[a:b]."""
    out = []
    depth = 0
    key = start = None
    for kind, x, y in tokens(s, a, b):
        if kind == "p":
            c = s[x]
            if c in "([{":
                depth += 1
            elif c in ")]}" or (c == "," and depth == 1):
                depth -= c != ","
                if depth <= 1 and key is not None:
                    out.append((key, start, x))
                    key = start = None
            elif c == ":" and depth == 1 and key is not None and start is None:
                start = y
        elif depth == 1 and key is None and kind in ("str", "id"):
            key = s[x + 1:y - 1] if kind == "str" else s[x:y]
    return out


def skill_files(bundle, loader):
    """(SKILL.md module, [(relative path, module)]) from a loader chunk exporting SKILL_MD and maybe SKILL_FILES."""
    md = loaded_file(bundle, loader, *loader.init_span(loader.exports["SKILL_MD"]))
    files = []
    if "SKILL_FILES" in loader.exports:
        entries = object_entries(loader.s, *loader.init_span(loader.exports["SKILL_FILES"]))
        files = [(rel, loaded_file(bundle, loader, x, y)) for rel, x, y in entries]
    return md, files


def embedded_loads(bundle, skill):
    """[(md module, supporting files)] of the embedded markdown skills whose frontmatter names `skill`."""
    out = []
    for name in bundle.mods:
        if name.endswith((".md", ".md.zst")) and frontmatter_name(bundle.text(name)) == skill:
            files = []
            for n in bundle.mods:
                if bundle.is_chunk(n) and bundle.contains(n, name) and bundle.contains(n, "SKILL_MD"):
                    md, more = skill_files(bundle, bundle.chunk(n))
                    if md == name:
                        files += more
            out.append((name, files))
    return out


def registered_loads(bundle, skill, roots):
    """[(md module, supporting files)] when a registration of `skill` loads a bundled SKILL_MD, itself or in a
    unit it calls; [] when it does not. Raises if it does but the loader cannot be followed."""
    scanned = []
    for chunk, i in roots:
        scanned.append(chunk.s[slice(*chunk.units[i])])
        for ident in chunk.refs(i):
            hit = lookup(bundle, chunk, ident)
            if hit:
                scanned.append(hit[0].s[slice(*hit[0].units[hit[1].unit])])
    if not any("SKILL_MD" in text for text in scanned):
        return []
    loaders = {m for text in scanned for m in re.findall(r'import\("(/\$bunfs/root/[^"]+\.js)"\)', text)
               if m in bundle.mods and "SKILL_MD" in bundle.chunk(m).exports}
    if not loaders:
        raise RuntimeError(f"{skill}: its registration loads a bundled SKILL_MD but no loader module was found")
    return [skill_files(bundle, bundle.chunk(m)) for m in sorted(loaders)]


def embedded_text(bundle, loads):
    parts = []
    for md, files in loads:
        parts.append(bundle.text(md).rstrip("\n"))
        for rel, path in files:
            parts.append(f"<!-- ===== FILE: {rel} ===== -->\n" + bundle.text(path).rstrip("\n"))
    return "\n\n".join(parts) + "\n"


# --- Inline skills ------------------------------------------------------

def registrations(bundle, skill):
    """[(chunk, unit index)] of every `fn({name:<skill>,...})` registration. The name is a string
    literal or a constant; a constant is only resolved when its chunk contains the literal."""
    literal = '"' + skill + '"'
    named = {n for n in bundle.mods if bundle.is_chunk(n) and bundle.contains(n, literal)}
    hits = []
    for name in bundle.mods:
        if not bundle.is_chunk(name) or not bundle.contains(name, "({name:"):
            continue
        chunk = bundle.chunk(name)
        for pos, ref in chunk.registrations:
            if ref[0] == '"':
                value = ref[1:-1]
            elif chunk.imports.get(ref, (name,))[0] in named:
                value = constant_value(bundle, chunk, ref)
            else:
                value = None
            if value == skill:
                hits.append((chunk, chunk.unit_at(pos)))
    return hits


def reachable(bundle, roots):
    """Nodes (chunk name, unit index) reachable from roots, each with its discovery rank."""
    best = {}
    order = {}
    stack = [((chunk, i), NON_PROMPT_HOPS) for chunk, i in roots]
    while stack:
        (chunk, i), budget = stack.pop()
        key = (chunk.name, i)
        if best.get(key, -1) >= budget:
            continue
        best[key] = budget
        order.setdefault(key, len(order))
        for ident in chunk.refs(i):
            hit = lookup(bundle, chunk, ident)
            if not hit or hit[1].unit == i and hit[0] is chunk:
                continue
            target, decl = hit
            near = target is chunk and abs(target.units[decl.unit][0] - chunk.units[i][0]) <= NEAR
            if not (near or target.prompt_dense(decl.unit)):
                continue
            if target.prompt_bearing(decl.unit):
                stack.append(((target, decl.unit), NON_PROMPT_HOPS))
            elif budget > 0:
                stack.append(((target, decl.unit), budget - 1))
    return order


def inline_text(bundle, skill, roots):
    order = reachable(bundle, roots)
    chunk_rank = {}
    for (cname, i), rank in order.items():
        chunk_rank.setdefault(cname, rank)
    literals = []
    for (cname, i) in sorted(order, key=lambda k: (chunk_rank[k[0]], k[1])):
        chunk = bundle.chunk(cname)
        if not chunk.prompt_bearing(i):
            continue
        a, b = chunk.units[i]
        for kind, x, y in tokens(chunk.s, a, b):
            if kind == "str":
                text = cook(chunk.s[x + 1:y - 1])
            elif kind == "tpl":
                text = render_template(bundle, chunk, x, y)
            else:
                continue
            if len(text) >= LITERAL_MIN:
                literals.append(text)
    if not literals:
        raise RuntimeError(f"{skill}: registered in {roots[0][0].name} but no prompt literal was reached")
    return INLINE_HEADER.format(skill) + "".join(f"\n<!-- literal -->\n{t}\n" for t in literals)


def extract(bundle, skill):
    """Text for `skill`, or None when the binary has no such skill."""
    loads = embedded_loads(bundle, skill)
    if loads:
        return embedded_text(bundle, loads)
    roots = registrations(bundle, skill)
    if not roots:
        return None
    loads = registered_loads(bundle, skill, roots)
    return embedded_text(bundle, loads) if loads else inline_text(bundle, skill, roots)


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)
    binary, outdir, skills = argv[1], argv[2], argv[3:]
    bundle = Bundle(binary)
    os.makedirs(outdir, exist_ok=True)
    missing = []
    for skill in skills:
        text = extract(bundle, skill)
        if text is None:
            missing.append(skill)
            continue
        with open(os.path.join(outdir, skill + ".md"), "w", encoding="utf-8") as f:
            f.write(text)
    if missing:
        sys.exit(f"error: built-in skill(s) not found in {binary}: {', '.join(missing)}\n"
                 "If Claude Code dropped them, remove them from the skills list in upstream.json; "
                 "otherwise the extractor no longer recognises how they are registered.")


if __name__ == "__main__":
    main(sys.argv)
