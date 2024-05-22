#!/bin/zsh

read -r -d '' usage <<EOF || true
Usage: $0 [--plot] [--topic TOPIC] ELF_PUB ELF_SUB

SYNOPSIS

  \$ $0 --plot libpublisher.so libsubscriber.so
  [ a realtime plot of latencies for ALL messages pops up ]

DESCRIPTION

This is a wrapper around a bpftrace script for ros2 tracing of communication
latencies. By default this runs bpftrace, and produces its output on stdout.
With --plot, this output is plotted in realtime.

If given, we only report the messages sent/received on the TOPIC. Otherwise we
report on all the topics

Arguments:

  --plot: if given, plot the latency in realtime

  --topic TOPIC: if given, only look for communcation on TOPIC

EOF

# comma-separated list of long options. Trailing : means "has required
# argument".
longopts='plot,topic:'
Ntrailing_options_required=2

# The parsing code to use getopt comes from
#   /usr/share/doc/util-linux/examples/getopt-example.bash
# I'm not an expert, but this sample makes things work
TEMP=$(getopt -o '' --long $longopts -n "$0" -- "$@")
[ $? -ne 0 ] && {
    echo '' > /dev/stderr
    echo $usage > /dev/stderr
    exit 1;
}
eval set -- "$TEMP"
unset TEMP
# The arguments now appear in a nice canonical order, and they are terminated by
# --

while {true} {
	case "$1" in
	        '--plot')
                        plot=1
                        shift
                        continue
                ;;

                '--topic')
                        topic=$2
                        shift 2
                        continue
                ;;

                '--')
                        shift
                        break
                ;;

                *)
                        echo 'Internal error in argument parsing' >&2
                        exit 1
                ;;
        esac
}

if (( $#* != Ntrailing_options_required )) {
       echo "Exactly $Ntrailing_options_required non-option arguments are required. Got $#* instead" > /dev/stderr
       echo '' > /dev/stderr
       echo $usage > /dev/stderr
       exit 1
}

# Need the absolute path to work around this bug:
#   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1063587
PUB_option=$1; shift;
SUB_option=$1; shift;

PUB=${PUB_option:A};
SUB=${SUB_option:A};

if ! [[ -f "$PUB" ]] {
       echo "Publisher option '$PUB_option' isn't a readable file" > /dev/stderr
       echo '' > /dev/stderr
       echo $usage > /dev/stderr
       exit 1
}
if ! [[ -f "$SUB" ]] {
       echo "Subscriber option '$SUB_option' isn't a readable file" > /dev/stderr
       echo '' > /dev/stderr
       echo $usage > /dev/stderr
       exit 1
}

if [[ -n "$topic" ]] {
  event_match_condition="\$topic == \"$topic\""
} else {
  event_match_condition="1"
  topic_legend=' topic'
  topic_format=' %s'
  topic_arg=',$topic'
}

# I print the legend here. bpftrace doesn't like my overly-long string, and I
# don't want to ask for more bpf memory just to print out the legend
cmd=(sudo zsh -c "echo '## Latency of received messages';
                  echo '# t_pub_ns tid_pub cpu_pub t_latency_take_ns tid_take cpu_take t_latency_sub_ns tid_sub cpu_sub$topic_legend';
                  bpftrace -q <( <ros2-comm-trace.bt \
                                 | sed 's@{{PUB}}@$PUB@g;
                                        s@{{SUB}}@$SUB@g;
                                        s@{{EVENT_MATCH_CONDITION}}@$event_match_condition@g;
                                        s@{{TOPIC_FORMAT}}@$topic_format@g;
                                        s@{{TOPIC_ARG}}@$topic_arg@g;'
                               )")

if ((plot)) {
    # The plotter is teed off. The data is always spit out to stdout
    $cmd | \
    tee >( vnl-filter \
             -p t_pub_s='rel(t_pub_ns)'/1e9,t_latency_take_ms=t_latency_take_ns/1e6,t_latency_sub_ms=t_latency_sub_ns/1e6 \
             --stream \
         | feedgnuplot \
             --domain \
             --stream \
             --vnl \
             --autolegend \
             --with 'linespoints pt 7' \
             --ymin 0 \
             --xlabel 'Publish time (s)' \
             --ylabel 'Latency (ms)' )
} else {
    $cmd
}
