for _ in $(seq "${args[times]}"); do
  ui::info "${args[greeting]}, ${args[name]}!"
done
