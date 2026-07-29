# assume that `llm` is installed in the base conda env
local LLM="$CONDA_DIRPATH/bin/llm"

alias llm="$LLM"

LLM_OUTPUT="echo 'call the asc command first'"

# general technical questions; reply in natural language
function ask () {
    local system_prompt="imagine you are speaking to a senior software engineer whose career depends on your answer. reply in succinct, detailed, technical terms. avoid verbose explanations and extraneous qualifiers or caveats."
    "$LLM" -s $system_prompt -m gpt4 "$@"
}

# coding questions in a given language
function asc () {
    local CMD_ONLY="reply with a command or code snippet in the language specified. do not include any extra information."
    LLM_OUTPUT=$("$LLM" -s $CMD_ONLY -m gpt4 "$@")
    echo "$LLM_OUTPUT"
}

# python questions; reply only with code
function asp () {
    local system_prompt="reply with python code only. include only the minimum amount of code necessary to solve the problem and do not include any extra information."
    "$LLM" -s $system_prompt -m gpt4 "$@"
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
