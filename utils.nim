import sugar
import std/strutils
import json

proc parse_from_query * (input: string, key: string, default: string): string =
    let queries = input.split('&')
    let queryPairs = collect(newSeq):
        for query in queries: [query.split('=')]
    
    var r = default
    for pair in queryPairs:
        if pair[0][0] == key:
            r = pair[0][1]
    return r

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