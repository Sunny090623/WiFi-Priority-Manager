# Formats stdin log lines into JSON array.
# Requires: lib_json.awk

BEGIN { init_ascii(); n = 0 }
{
  line = $0; sub(/\r$/, "", line)
  if (line != "") { n++; lines[n] = line }
}
END {
  printf "{\"logs\":["
  for (i = 1; i <= n; i++) {
    printf "%s\"%s\"", (i > 1 ? "," : ""), json_escape(lines[i])
  }
  printf "]}\n"
}
