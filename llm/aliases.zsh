# assume that `llm` is installed in the base conda env
local LLM="$HOME/opt/miniconda3/bin/llm"

alias llm="$LLM"

function asc () {
    local CMD_ONLY="reply with macos terminal commands only. do not include any extra information."
    "$LLM" -s $CMD_ONLY "$@"
}

function ask () {
    local ENG_ONLY="imagine you are speaking to a senior software engineer. reply in succinct, detailed, technical terms. avoid extraneous explanations, qualifiers, and caveats."
    "$LLM" -s $ENG_ONLY "$@"
}
