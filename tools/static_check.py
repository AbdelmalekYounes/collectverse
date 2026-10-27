"""Vérifications statiques légères du code Luau, sans outil Roblox installé.

Ce script NE remplace PAS luau-analyze, selene ou un test dans Studio. Il détecte :
  - les blocs déséquilibrés (function/if/do ... end), y compris les if-expressions Luau ;
  - les parenthèses, crochets et accolades déséquilibrés ;
  - les opérateurs d'autres langages (!=, &&, ||) ;
  - les require() dont la cible n'existe pas dans l'arbre Rojo (default.project.json).

Usage : python tools/static_check.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT_SUFFIXES = (".server.luau", ".client.luau", ".luau")

# ---------------------------------------------------------------------------
# Lexique minimal
# ---------------------------------------------------------------------------

TOKEN_RE = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<longcomment>--\[(?P<lceq>=*)\[.*?\](?P=lceq)\])
  | (?P<comment>--[^\n]*)
  | (?P<longstring>\[(?P<lseq>=*)\[.*?\](?P=lseq)\])
  | (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)
  | (?P<number>0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|%=|\^=|->|::|!=|&&|\|\||[-+*/%^#<>=(){}\[\];:,.?&|!])
    """,
    re.VERBOSE | re.DOTALL,
)


def tokenize(source: str, path: Path, errors: list[str]) -> list[tuple[str, str, int]]:
    tokens = []
    pos = 0
    line = 1
    while pos < len(source):
        match = TOKEN_RE.match(source, pos)
        if not match:
            errors.append(f"{path}:{line}: caractère inattendu {source[pos]!r}")
            pos += 1
            continue
        kind = match.lastgroup
        text = match.group(0)
        if kind in ("lceq", "lseq"):
            kind = "longstring"
        if kind not in ("ws", "comment", "longcomment"):
            if kind == "longstring" and text.startswith("--"):
                kind = "longcomment"
            else:
                tokens.append((kind, text, line))
        line += text.count("\n")
        pos = match.end()
    return tokens


# Après ces jetons, un `if` est une if-expression (sans `end`).
EXPRESSION_CONTEXT = {
    "=", "(", ",", "{", "[", "return", "and", "or", "not", "..", "+", "-", "*", "/", "%", "^",
    "==", "~=", "<", ">", "<=", ">=", "+=", "-=", "*=", "/=", "..=", "#",
}
OPENERS = {"function", "do", "then_if"}
PAIRS = {")": "(", "]": "[", "}": "{"}


def check_blocks(tokens, path: Path, errors: list[str]) -> None:
    stack: list[tuple[str, int]] = []
    brackets: list[tuple[str, int]] = []
    previous = None
    for kind, text, line in tokens:
        if kind == "op":
            if text in ("!=", "&&", "||"):
                errors.append(f"{path}:{line}: opérateur non Luau {text!r}")
            if text in "([{":
                brackets.append((text, line))
            elif text in ")]}":
                if not brackets or brackets[-1][0] != PAIRS[text]:
                    errors.append(f"{path}:{line}: {text!r} sans ouverture correspondante")
                else:
                    brackets.pop()
        elif kind == "name":
            # `t.end` ou `obj:if` ne sont pas des mots-clés
            is_field = previous is not None and previous[1] in (".", ":")
            if not is_field:
                if text == "function":
                    stack.append(("function", line))
                elif text == "do":
                    stack.append(("do", line))
                elif text == "if":
                    if previous is None or previous[1] not in EXPRESSION_CONTEXT:
                        stack.append(("if", line))
                elif text == "repeat":
                    stack.append(("repeat", line))
                elif text == "until":
                    if not stack or stack[-1][0] != "repeat":
                        errors.append(f"{path}:{line}: 'until' sans 'repeat'")
                    else:
                        stack.pop()
                elif text == "end":
                    if not stack or stack[-1][0] == "repeat":
                        errors.append(f"{path}:{line}: 'end' en trop")
                    else:
                        stack.pop()
        previous = (kind, text)
    for opener, line in stack:
        errors.append(f"{path}:{line}: '{opener}' jamais fermé")
    for opener, line in brackets:
        errors.append(f"{path}:{line}: {opener!r} jamais fermé")


# ---------------------------------------------------------------------------
# Arbre Rojo et résolution des require
# ---------------------------------------------------------------------------


def instance_name(path: Path) -> tuple[str, str] | None:
    name = path.name
    if name.endswith(".server.luau"):
        return name[: -len(".server.luau")], "Script"
    if name.endswith(".client.luau"):
        return name[: -len(".client.luau")], "LocalScript"
    if name.endswith(".luau"):
        return name[: -len(".luau")], "ModuleScript"
    return None


def build_tree(project: dict) -> tuple[dict, dict]:
    """Renvoie {chemin d'instance: classe} et {fichier: chemin d'instance}."""
    instances: dict[tuple[str, ...], str] = {(): "DataModel"}
    files: dict[Path, tuple[str, ...]] = {}

    def add_dir(directory: Path, prefix: tuple[str, ...]) -> None:
        for child in sorted(directory.iterdir()):
            if child.is_dir():
                instances[prefix + (child.name,)] = "Folder"
                add_dir(child, prefix + (child.name,))
            else:
                parsed = instance_name(child)
                if parsed:
                    instances[prefix + (parsed[0],)] = parsed[1]
                    files[child.resolve()] = prefix + (parsed[0],)

    def walk(node: dict, prefix: tuple[str, ...]) -> None:
        if "$path" in node:
            target = ROOT / node["$path"]
            if not target.exists():
                raise SystemExit(f"default.project.json : chemin introuvable {node['$path']}")
            instances[prefix] = "Folder"
            add_dir(target, prefix)
        for key, child in node.items():
            if not key.startswith("$"):
                instances[prefix + (key,)] = child.get("$className", "Service")
                walk(child, prefix + (key,))

    walk(project["tree"], ())
    return instances, files


SERVICE_RE = re.compile(r'game:GetService\("(\w+)"\)')


def parse_chain(tokens, start: int, variables: dict, script_path: tuple[str, ...]):
    """Analyse une expression comme `script.Parent.X:WaitForChild("Y")`.

    Renvoie (chemin d'instance ou None, index du jeton suivant).
    """
    kind, text, _ = tokens[start]
    index = start + 1
    if text == "script":
        path = list(script_path)
    elif text == "game" and index + 3 < len(tokens) and tokens[index][1] == ":" and tokens[index + 1][1] == "GetService":
        service = tokens[index + 3][1].strip('"')
        path = [service]
        index += 5  # : GetService ( "X" )
    elif text in variables and variables[text] is not None:
        path = list(variables[text])
    else:
        return None, index

    while index < len(tokens):
        current = tokens[index][1]
        if current == "." and index + 1 < len(tokens) and tokens[index + 1][0] == "name":
            name = tokens[index + 1][1]
            if name == "Parent":
                if not path:
                    return None, index
                path.pop()
            else:
                path.append(name)
            index += 2
        elif (
            current == ":"
            and index + 4 < len(tokens)
            and tokens[index + 1][1] in ("WaitForChild", "FindFirstChild")
            and tokens[index + 3][0] == "string"
        ):
            path.append(tokens[index + 3][1][1:-1])
            index += 5
            # Ignore un éventuel délai : WaitForChild("X", 30)
            if tokens[index - 1][1] == ",":
                while index < len(tokens) and tokens[index][1] != ")":
                    index += 1
                index += 1
        else:
            break
    return tuple(path), index


def check_requires(tokens, path: Path, script_path, instances, errors: list[str]) -> int:
    variables: dict[str, tuple[str, ...] | None] = {}
    checked = 0
    for i, (kind, text, line) in enumerate(tokens):
        # local Name = <chaîne>
        if text == "local" and i + 3 < len(tokens) and tokens[i + 1][0] == "name" and tokens[i + 2][1] == "=":
            resolved, end = parse_chain(tokens, i + 3, variables, script_path)
            # On ne retient que les chaînes entières (pas un appel de fonction ensuite)
            if resolved is not None and end < len(tokens) and tokens[end][1] not in ("(", "[", ":"):
                variables[tokens[i + 1][1]] = resolved
            else:
                variables[tokens[i + 1][1]] = None
        if text == "require" and i + 2 < len(tokens) and tokens[i + 1][1] == "(":
            resolved, end = parse_chain(tokens, i + 2, variables, script_path)
            if resolved is None:
                continue  # expression dynamique (ex. require(module) dans le runner)
            checked += 1
            target = instances.get(resolved)
            if target is None:
                errors.append(f"{path}:{line}: require introuvable {'.'.join(resolved)}")
            elif target != "ModuleScript":
                errors.append(f"{path}:{line}: require d'un {target} ({'.'.join(resolved)})")
    return checked


def main() -> int:
    project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    instances, files = build_tree(project)

    errors: list[str] = []
    file_count = 0
    require_count = 0
    for file, script_path in sorted(files.items()):
        relative = file.relative_to(ROOT)
        source = file.read_text(encoding="utf-8")
        tokens = tokenize(source, relative, errors)
        check_blocks(tokens, relative, errors)
        require_count += check_requires(tokens, relative, script_path, instances, errors)
        file_count += 1

    print(f"{file_count} fichiers Luau, {require_count} require résolus statiquement")
    if errors:
        for message in errors:
            print("ERREUR", message)
        print(f"{len(errors)} erreur(s)")
        return 1
    print("Aucune erreur détectée")
    return 0


if __name__ == "__main__":
    sys.exit(main())
