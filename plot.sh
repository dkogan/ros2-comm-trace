#!/bin/zsh

# Read STDIN from probe.sh, and make a plot

vnl-filter \
    --has t_latency_sub_ns \
    -p t='rel(t_ns)'/1e9,t_latency_take_ms=t_latency_take_ns/1e6,t_latency_sub_ms=t_latency_sub_ns/1e6 \
    --stream \
| feedgnuplot \
    --domain \
    --stream \
    --vnl \
    --autolegend \
    --with 'linespoints pt 7' \
    --ymin 0 \
    --xlabel 'Publish time (s)' \
    --ylabel 'Latency (ms)'
