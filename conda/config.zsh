# ugly way to determine the path to the conda installation
possible_dirpaths=("$HOME/opt/miniconda3" "$HOME/miniforge3")

for dir in "${possible_dirpaths[@]}"; do
    if [ -f "$dir/etc/profile.d/conda.sh" ]; then
        CONDA_DIRPATH="$dir"
        break
    fi
done

unset possible_dirpaths
