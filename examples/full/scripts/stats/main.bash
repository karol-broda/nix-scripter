ui::header "Store statistics"
total=5
for ((i = 1; i <= total; i++)); do
  ui::progress "$i" "$total" "Scanning"
done
printf 'kind\tcount\npaths\t%s\nroots\t%s\n' 42 7 | ui::table
