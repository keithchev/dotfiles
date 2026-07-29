function act-w() {
  local files=(.github/workflows/"$1"*.(yaml|yml))
  act -W "${files[1]}" "$@"
}
