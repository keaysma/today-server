import nimsha2
import std/encodings

let digest = computeSHA256("test value")
let s = convert($digest)
echo(s)