#!/bin/zsh

read -r -d '' usage <<EOF || true
Usage: $0 [--plot] ELF_PUB ELF_SUB

SYNOPSIS

  \$ $0 --plot libpublisher.so libsubscriber.so
  [ a realtime plot of latencies pops up ]

DESCRIPTION

This is a wrapper around a bpftrace script for ros2 tracing of communication
latencies. By default this runs bpftrace, and produces its output on stdout.
With --plot, this output is plotted in realtime

Arguments:

  --plot: if given, plot the latency in realtime

EOF

# comma-separated list of long options. Trailing : means "has required
# argument".
longopts='plot'
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

cmd=(sudo zsh -c "bpftrace -q <( <ros2-comm-trace.bt | sed 's@{{PUB}}@$PUB@g; s@{{SUB}}@$SUB@g;' )")

if ((plot)) {
   $cmd \
       | vnl-filter -p t_measured_ms=t_measured_ns/1e6 --stream \
       | feedgnuplot --stream --vnl --autolegend --with 'linespoints pt 7' --ymin 0 --ylabel 'Latency (ms)'
} else {
   $cmd
}
