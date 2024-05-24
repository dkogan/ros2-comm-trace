#!/bin/zsh

# Read STDIN from probe.sh, and make a plot
#
# --stream may be passed, and will be fed to the vnl-filter and the feedgnuplot.
#
# temporarily I --begin '$| = 1;' below. vnl-filter --stream --perl should do
# that for me
vnl-filter --perl \
  --begin '$| = 1;' \
  --sub 'report_switch_to {   $t                      = shift;
                              $task_switching_to      = shift;
                              $task_switching_to_prio = shift;

                              # say STDERR "t=$t task_switching_to=$task_switching_to task_switching_to_prio=$task_switching_to_prio";

                              return unless $t_waking{$task_switching_to} && $t_start{$task_switching_to};

                              # plot the "waking" arc. This is a line segment from the waking task to the wakee task
                              $waker = $task_waking{$task_switching_to};
                              $dx = $t_waking{$task_switching_to} - $t_start{$waker};
                              $dy = to_cpu - $cpu_start{$waker};

                              # say STDERR "plotting the waking arc; task_waking{task_switching_to}=$task_waking{$task_switching_to} t_waking{task_switching_to}=$t_waking{$task_switching_to} t_start_{task_waking{task_switching_to}} = $t_start{$task_waking{$task_switching_to}} dx=$dx";

                              # switching latencies > 500ms are probably bogus,
                              # and I dont plot them. I dont record ALL the events, and its possible that I
                              # missed some crucial ones, causing these fictitiously-high latencies to be shown
                              #

                              # Sometimes we see being switched to a task
                              # without seeing the sched_waking or sched_wakeup. In those cases well see dx<0,
                              # and I simply dont plot the arc
                              if($dx < 0.5 && $dx > 0)
                              {
                                say "$t_start{$waker} wake $cpu_start{$waker}";
                                if($dy == 0)
                                {
                                  # We are on the same cpu; make an arc for clearer visualization
                                  say "" . ($t_start{$waker} + $dx/2.) . " wake " . (to_cpu+0.2);
                                }
                                say "$t_waking{$task_switching_to} wake to_cpu";
                                say "0 wake nan"; # bogus point to separate the arcs
                              }
}' \
  --sub 'report_switch_from { $t                        = shift;
                              $task_switching_from      = shift;
                              $task_switching_from_prio = shift;

                              return unless $t_waking{$task_switching_from} && $t_start{$task_switching_from};

                              $task_description = "$task_switching_from:prio=$task_switching_from_prio";

                              # Plot the "waking event and the on-cpu interval. This is an xerrorbar"
                              say "$t_waking{$task_switching_from} $task_description to_cpu $t_start{$task_switching_from} $t";
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

            if(exists $t_start{$task_from}) {
              # I want to plot the "waking" arc. The to_cpu is unreliable here,
              # and I plot this later, during the switch, since THAT will know the correct
              # to_cpu
              $t_waking   {$task_to} = $t;
              $task_waking{$task_to} = $task_from;
            } else {
              # Unknown task woke us up. I reset the states so that I dont plot a bogus waking arc
              $t_waking   {$task_to} = undef;
              $task_waking{$task_to} = undef;
            }
          }
          elsif(sched eq "switch") {
            $t_start{to}   = $t;
            $cpu_start{to} = to_cpu;
            report_switch_to(  $t, to,   to_prio);
            report_switch_from($t, from, from_prio);
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
