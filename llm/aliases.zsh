# assume that `llm` is installed in the base conda env
local LLM="$HOME/opt/miniconda3/bin/llm"

alias llm="$LLM"

LLM_OUTPUT="echo 'call the asc command first'"

function asc () {
    local CMD_ONLY="reply with macos terminal commands only. do not include any extra information."
    LLM_OUTPUT=$("$LLM" -s $CMD_ONLY -m gpt4 "$@")
    echo "$LLM_OUTPUT"
}

function ask () {
    local ENG_ONLY="imagine you are speaking to a senior software engineer. reply in succinct, detailed, technical terms. avoid verbose explanations and extraneous qualifiers or caveats."
    "$LLM" -s $ENG_ONLY -m gpt4 "$@"
}

function evalasc () {
    eval "$LLM_OUTPUT"
}
