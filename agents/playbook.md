
- zsh does not word-split unquoted `$var`: `set -- $cfg` or `for a b in $pairs` passes one string, and a `sed -E "s/= [^;]+;/= $1;/"` sweep then writes garbage (or an empty value) into the file. For parameter sweeps call a function with explicit arguments (`run 4.0 2.5`) and edit with a Python regex that tolerates an empty value; `grep` the edited line before each run.
