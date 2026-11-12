function fish_greeting
    # Date · uptime · weather
    set -l up (uptime | string match -r 'up\s+(.*?),\s+\d+ users?' --groups-only | string replace -ra '\s+' ' ')
    set -l line (date '+%a %b %d, %H:%M')"  ·  up $up"
    set -l wx (__greeting_weather)
    test -n "$wx"; and set line "$line  ·  $wx"
    set_color brblack; echo $line
    # Show the °F→°C conversion worked out with today's numbers
    set -l f (string match -r '([+-]?\d+)°F' --groups-only -- $wx | string replace -r '^\+' '')
    if test -n "$f"
        set -l exact (math -s0 "round(($f - 32) * 5 / 9)")
        set -l quick (math -s0 "round(($f - 30) / 2)")
        echo "   °C = ($f − 32) × 5⁄9 = $exact   ·   quick: ($f − 30) ÷ 2 ≈ $quick"
    end
    set_color normal

    # System snapshot (config: ~/.config/fastfetch/greeting.jsonc)
    if type -q fastfetch
        fastfetch --config ~/.config/fastfetch/greeting.jsonc --pipe false
    end

    # Random shortcut reminder (edit ~/.config/fish/tips.txt)
    set -l tips (string match -rv '^\s*(#|$)' < ~/.config/fish/tips.txt)
    if test (count $tips) -gt 0
        echo
        set_color brblack; echo -n 'tip  '; set_color normal
        echo $tips[(random 1 (count $tips))]
    end
end

# Weather from wttr.in, cached for 30 min and refreshed in the background
# so a slow or missing network never delays the prompt.
function __greeting_weather
    set -l cache ~/.cache/fish/wttr.txt
    set -l ttl 1800
    mkdir -p (dirname $cache)

    set -l stale 1
    if test -f $cache
        set -l age (math (date +%s) - (path mtime $cache))
        test $age -lt $ttl; and set stale 0
    end

    if test $stale -eq 1
        # Refresh in a detached subshell. Only replace the cache when the
        # response is short, non-empty, and not an HTML error page.
        fish -c "
            set -l tmp $cache.tmp.\$fish_pid
            if curl -fsS --connect-timeout 2 -m 5 'wttr.in/?format=%c+%t+%w+%h&u' -o \$tmp 2>/dev/null
                set -l body (string trim < \$tmp)
                if test -n \"\$body\"; and test (string length \"\$body\") -lt 60; and not string match -qi '*<html*' -- \$body
                    printf '%s' \$body > $cache
                end
            end
            rm -f \$tmp
        " >/dev/null 2>&1 &
        disown 2>/dev/null
    end

    test -f $cache; or return
    # Append Celsius next to the Fahrenheit reading, e.g. "+63°F" -> "63°F / 17°C"
    set -l raw (cat $cache)
    set -l f (string match -r '([+-]?\d+)°F' --groups-only -- $raw)
    if test -n "$f"
        set -l c (math -s0 "round(($f - 32) * 5 / 9)")
        echo (string replace -r '[+-]?\d+°F' "$f°F / $c°C" -- $raw)
    else
        echo $raw
    end
end
