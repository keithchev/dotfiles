# assume that `llm` is installed in the base conda env
local LLM="$CONDA_DIRPATH/bin/llm"

alias llm="$LLM"

LLM_OUTPUT="echo 'call the asc command first'"

# coding questions
function asc () {
    local CMD_ONLY="reply with a command or code snippet in the language specified. do not include any extra information."
    LLM_OUTPUT=$("$LLM" -s $CMD_ONLY -m gpt4 "$@")
    echo "$LLM_OUTPUT"
}

# general technical questions
function ask () {
    local ENG_ONLY="imagine you are speaking to a senior software engineer. reply in succinct, detailed, technical terms. avoid verbose explanations and extraneous qualifiers or caveats."
    "$LLM" -s $ENG_ONLY -m gpt4 "$@"
}

# macos terminal commands
function ast () {
    local CMD_ONLY="reply with macos terminal commands only. do not include any extra information."
    LLM_OUTPUT=$("$LLM" -s $CMD_ONLY -m gpt4 "$@")
    echo "$LLM_OUTPUT"
}

function eval-ast () {
    eval "$LLM_OUTPUT"
}
