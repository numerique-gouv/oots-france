#!/bin/sh
# PostToolUse hook on the Linear MCP writes. Their answer is the whole ticket — 10 Ko in median,
# 25 Ko for a mature one, for an input of a few hundred bytes — and it lands in the model's context
# whether anyone reads it or not. This keeps one line of it: what was written, its status, its URL.
# A failed write never reaches this hook (PostToolUse fires on success only), so nothing is lost.
# Input on stdin: {tool_name, tool_input, tool_response, ...}; for an MCP tool, tool_response is
# a list of text blocks whose text is the JSON of the issue or comment.
jq -c '
  def body: .tool_response
    | (if type == "array" then map(select(.type == "text") | .text) | join("") else tostring end)
    | (try fromjson catch {});
  (body) as $b
  | ($b.identifier // $b.id // .tool_input.id // "?") as $id
  | (if .tool_name == "mcp__linear__save_comment"
     then "OK comment \($b.id // "?") on \(.tool_input.issueId // .tool_input.parentId // "?")"
     else "OK \($id) \($b.status // $b.state // "?") \($b.url // "")" end) as $line
  | {hookSpecificOutput: {hookEventName: "PostToolUse", updatedToolOutput: $line}}
'
