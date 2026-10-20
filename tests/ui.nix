{
  pkgs,
  lib,
  scripter,
  runTest,
  inTerminal,
  ...
}:
let
  uiScript = scripter.bash {
    name = "ui-demo";
    features.ui = true;
    src = ./fixtures/ui-demo.bash;
  };
in
{
  ui-plain = runTest "ui-plain" [ ] ''
    ${uiScript}/bin/ui-demo > stdout.txt 2> stderr.txt
    [ "$(cat stdout.txt)" = "$(printf 'from command\nstdout stays clean')" ] || fail "stdout polluted: $(cat stdout.txt)"
    for line in "== Header ==" "-- Section" "[info] an info" "[warn] a warning" \
      "[error] an error" "[ok] a success" "  - one" "==> Group" "==> Command group" \
      "[warn] check this (src/main.c:42)" "[info] Spinning ..." "[ok] Spinning" \
      "[info] Copying: 50%" "[info] Copying: 100%"; do
      expect_contains stderr.txt "$line"
    done
    expect_not_contains stderr.txt "a debug"
    expect_not_contains stderr.txt "s3cret"
    printf 'a\tbb\nccc\td\n' > table.txt
    grep -qF "$(printf 'ccc\td')" stderr.txt || fail "plain table is not TSV"

    SCRIPTER_LOG_LEVEL=debug ${uiScript}/bin/ui-demo 2> debug.txt > /dev/null
    expect_contains debug.txt "[debug] a debug"
    SCRIPTER_LOG_LEVEL=warn ${uiScript}/bin/ui-demo 2> warn.txt > /dev/null
    expect_not_contains warn.txt "an info"
    expect_contains warn.txt "a warning"
  '';
  ui-github = runTest "ui-github" [ ] ''
    GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> gh.txt > /dev/null
    for line in "::warning::a warning" "::error::an error" "::group::Group" "::endgroup::" \
      "::group::Command group" "::warning file=src/main.c,line=42::check this" "::add-mask::s3cret"; do
      expect_contains gh.txt "$line"
    done
    expect_contains gh.txt "$(printf '\e[34m')"
    NO_COLOR=1 GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> nocolor.txt > /dev/null
    expect_not_contains nocolor.txt "$(printf '\e[')"
  '';
  ui-other-ci = runTest "ui-other-ci" [ ] ''
    GITLAB_CI=true ${uiScript}/bin/ui-demo 2> gitlab.txt > /dev/null
    expect_contains gitlab.txt "section_start:"
    expect_contains gitlab.txt "[collapsed=true]"
    expect_contains gitlab.txt "section_end:"
    TF_BUILD=True ${uiScript}/bin/ui-demo 2> azure.txt > /dev/null
    expect_contains azure.txt "##vso[task.logissue type=warning]a warning"
    expect_contains azure.txt "##[group]Group"
    TEAMCITY_VERSION=1 ${uiScript}/bin/ui-demo 2> tc.txt > /dev/null
    expect_contains tc.txt "##teamcity[blockOpened name='Group']"
    SCRIPTER_CI=none GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> forced.txt > /dev/null
    expect_contains forced.txt "[warn] a warning"
  '';
  ui-fancy = runTest "ui-fancy" [ ] ''
    ${inTerminal} ${uiScript}/bin/ui-demo > tty.txt
    expect_contains tty.txt "$(printf '\e[1m')"
    expect_contains tty.txt "an info"
    SCRIPTER_ICONS=unicode ${inTerminal} ${uiScript}/bin/ui-demo > unicode.txt
    expect_contains unicode.txt "✔"
  '';
}
