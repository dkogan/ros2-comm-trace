#!/bin/zsh

# Read STDIN from probe.sh, and make a plot
#
# --stream may be passed, and will be fed to the vnl-filter and the feedgnuplot.
#
# temporarily I --begin '$| = 1;' below. vnl-filter --stream --perl should do
# that for me
vnl-filter --perl \
  --begin '$| = 1;' \
  --sub 'report_switch { $t    = shift;
                         $task = shift;
                         return unless $t_waking{$task} && $t_start{$task};
                         say "$t_waking{$task} $task_description{$task} to_cpu $t_start{$task} $t" }' \
  --eval '$t = rel(t_ns)/1e9;
          if(defined t_latency_sub_ns) {
            $t_latency_take_ms = t_latency_take_ns/1e6;
            $t_latency_sub_ms  = t_latency_sub_ns /1e6;
            say "$t t_latency_take_ms $t_latency_take_ms t_latency_sub_ms $t_latency_sub_ms";
          }
          elsif(sched eq "waking") {
            $task_from = from;
            $task_to   = to;
            $t_waking{$task_to}   = $t;
            $task_description{$task_to} = "$task_from:from_pid:prio=from_prio->$task_to:to_pid:prio=to_prio";
          }
          elsif(sched eq "switch") {
            $t_start{to}   = $t;
            $cpu_start{to} = to_cpu;
            report_switch($t, from);
          }' \
| feedgnuplot                                                              \
    $*                                                                     \
    --dataid                                                               \
    --domain                                                               \
    --with 'xerrorbars lw 2 pt 7'                                          \
    --tuplesizeall 4                                                       \
    --autolegend                                                           \
    --ylabel 'CPU'                                                         \
    --y2        t_latency_take_ms,t_latency_sub_ms                         \
    --tuplesize t_latency_take_ms,t_latency_sub_ms 2                       \
    --style     t_latency_take_ms,t_latency_sub_ms 'with linespoints pt 7' \
    --set       'errorbars 4'                                              \
    --y2min 0                                                              \
    --xlabel 'Time (s)'                                                    \
    --y2label 'Latency (ms)'
