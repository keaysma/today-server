import nimsha2
import sugar
import std/algorithm
import std/encodings
import std/strutils
import std/times
import std/uri
import std/os
import json

proc parse_from_query * (input: string, key: string, default: string): string =
    let queries = input.split('&')
    let queryPairs = collect(newSeq):
        for query in queries: [query.split('=')]
    
    result = default
    for pair in queryPairs:
        if pair[0][0] == key:
            result = pair[0][1].decodeUrl
            

proc parse_pg_array * (input: string): seq[string] =
    return input
        .replace("{", "")
        .replace("}", "")
        .split(",")

proc parse_json_array * (input: JsonNode): seq[string] =
    return ($input)
        .replace("[", "")
        .replace("]", "")
        .split(",")

proc make_database_tags * (tags: seq[string]): string =
    let lower_tags = collect(newSeq):
        for tag in tags: toLower(tag)
    let sorted_tags = sorted(lower_tags, system.cmp[string])
    return "{" & sorted_tags.join(",") & "}"

proc make_database_tuple * (values: seq): string =
    return "(" & values.join(",") & ")"

proc make_password_hash * (raw_password: string): string =
    var sha = initSHA[SHA256]()
    sha.update(getEnv("salt"))
    sha.update(raw_password)
    let digest = sha.final()
    return convert(digest.toHex(), "UTF-8")

proc make_session_token * (seed: string): string =
    var sha = initSHA[SHA256]()
    sha.update(getEnv("salt"))
    sha.update(seed)
    sha.update($now())
    let digest = sha.final()
    return convert(digest.toHex(), "UTF-8")