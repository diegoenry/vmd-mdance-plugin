# export_beats.tcl - dump every declared beat to JSON for the narration builder.
#
#   tclsh8.6 demo/narration/export_beats.tcl demo/narration/beats.json
#
# Runs under a PLAIN tclsh: the scene files must be pure declarations, and the
# -do bodies are never evaluated here. That is the whole reason the walkthrough
# is written as data rather than as a script -- the same file feeds the
# text-to-speech build and the live run, so the voice-over can never describe an
# action the demo does not actually perform.

set here [file dirname [file normalize [info script]]]
set demo_root [file dirname $here]

source [file join $demo_root tcl demo_dsl.tcl]

# json_str - encode a Tcl string as a JSON string literal.
proc json_str {s} {
    set map [list \
        "\\" "\\\\" \
        "\"" "\\\"" \
        "\b" "\\b" \
        "\f" "\\f" \
        "\n" "\\n" \
        "\r" "\\r" \
        "\t" "\\t"]
    set s [string map $map $s]
    # Escape any remaining control characters; a stray one would make the JSON
    # unparseable on the Python side with a very unhelpful message.
    set out ""
    foreach ch [split $s ""] {
        scan $ch %c code
        if {$code < 0x20} {
            append out [format "\\u%04x" $code]
        } else {
            append out $ch
        }
    }
    return "\"$out\""
}

::demo::load_scenes [file join $demo_root tcl scenes]

set scenes [::demo::scene_ids]
if {[llength $scenes] == 0} {
    puts stderr "export_beats: no scenes found in [file join $demo_root tcl scenes]"
    exit 1
}

set out [open [lindex $argv 0] w]
puts $out "\{"
puts $out "  \"scenes\": \["
set first_scene 1
foreach sid $scenes {
    set sc [::demo::scene_get $sid]
    if {!$first_scene} { puts $out "    ," }
    set first_scene 0
    puts $out "    \{"
    puts $out "      \"id\": [json_str $sid],"
    puts $out "      \"title\": [json_str [dict get $sc title]],"
    puts $out "      \"subtitle\": [json_str [dict get $sc subtitle]],"
    puts $out "      \"beats\": \["
    set first_beat 1
    foreach b [dict get $sc beats] {
        if {!$first_beat} { puts $out "        ," }
        set first_beat 0
        puts $out "        \{"
        puts $out "          \"id\": [json_str [dict get $b id]],"
        puts $out "          \"caption\": [json_str [dict get $b caption]],"
        puts $out "          \"say\": [json_str [dict get $b say]],"
        # -at is a string, not a number: "0.6f" (a fraction of the narration) is
        # a legal value and would be invalid JSON unquoted.
        puts $out "          \"at\": [json_str [dict get $b at]],"
        puts $out "          \"hold\": [dict get $b hold]"
        puts $out "        \}"
    }
    puts $out "      \]"
    puts $out "    \}"
}
puts $out "  \]"
puts $out "\}"
close $out

set n 0
foreach sid $scenes { incr n [llength [::demo::scene_beats $sid]] }
puts "export_beats: [llength $scenes] scenes, $n beats -> [lindex $argv 0]"
