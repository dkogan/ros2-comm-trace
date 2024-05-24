#!/bin/zsh

# Read STDIN from probe.sh, and make a plot
#
# --stream may be passed, and will be fed to the vnl-filter and the feedgnuplot.
#
# temporarily I --begin '$| = 1;' below. vnl-filter --stream --perl should do
# that for me
vnl-filter --perl \
  --begin '$| = 1;' \
  --sub 'report_switch { $t_switching_from    = shift;
                         $task_switching_from = shift;
                         return unless $t_waking{$task_switching_from} && $t_start{$task_switching_from};
                         say "$t_waking{$task_switching_from} $task_description{$task_switching_from} to_cpu $t_start{$task_switching_from} $t_switching_from";

                         # plot the "waking" arc
                         $waker = $task_waker{$task_switching_from};
                         $dx = $t_waking{$task_switching_from} - $t_start{$waker};
                         $dy = to_cpu - $cpu_start{$waker};

                         say "$t_start{$waker} wake $cpu_start{$waker}";
                         if($dy == 0)
                         {
                           # We are on the same cpu; make an arc for clearer visualization
                           say "" . ($t_start{$waker} + $dx/2.) . " wake " . (to_cpu+0.2);
                         }
                         say "$t_waking{$task_switching_from} wake to_cpu";
                         say "0 wake nan"; # bogus point to separate the arcs

}' \
  --eval '$t = rel(t_ns)/1e9;
          if(defined t_latency_sub_ns) {
            $t_latency_take_ms = t_latency_take_ns/1e6;
            $t_latency_sub_ms  = t_latency_sub_ns /1e6;
            say "$t  t_latency_take_ms $t_latency_take_ms t_latency_sub_ms $t_latency_sub_ms";
            $t0 = $t+$t_latency_take_ms/1e3;
            say "$t0 t_latency_take_ms $t_latency_take_ms t_latency_sub_ms $t_latency_sub_ms";
            $t0 = $t+$t_latency_sub_ms/1e3;
            say "$t0 t_latency_take_ms $t_latency_take_ms t_latency_sub_ms $t_latency_sub_ms";
          }
          elsif(sched eq "waking") {
            $task_from = from;
            $task_to   = to;
            $t_waking{$task_to}   = $t;
            $task_description{$task_to} = "$task_to:prio=to_prio";

            if(exists $t_start{from}) {
              # I want to plot the "waking" arc. The to_cpu is unreliable here,
              # and I plot this later, during the switch, since THAT will know the correct
              # to_cpu
              $task_waker{to} = from;
            }
          }
          elsif(sched eq "switch") {
            $t_start{to}   = $t;
            $cpu_start{to} = to_cpu;
            report_switch($t, from); # plot the just-completed task
          }' \
| feedgnuplot                                                              \
    $*                                                                     \
    --dataid                                                               \
    --domain                                                               \
    --with 'xerrorbars lw 2 pt 7'                                          \
    --tuplesizeall 4                                                       \
    --autolegend                                                           \
    --ylabel 'CPU'                                                         \
    --style     wake 'with lines smooth bezier'                            \
    --tuplesize wake 2                                                     \
    --y2        t_latency_take_ms,t_latency_sub_ms                         \
    --tuplesize t_latency_take_ms,t_latency_sub_ms 2                       \
    --style     t_latency_take_ms,t_latency_sub_ms 'with linespoints pt 7' \
    --set       'errorbars 4'                                              \
    --y2min 0                                                              \
    --xlabel 'Time (s)'                                                    \
    --y2label 'Latency (ms)'
