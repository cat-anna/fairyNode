uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
wifi.setmode(wifi.NULLMODE)
node.setcpufreq(node.CPU160MHZ)

print "INIT: Starting fairyNode"
print "INIT: Waiting before entering bootstrap..."
tmr.create():alarm(
  1000,
  tmr.ALARM_SINGLE,
  function(t)
    t:unregister()
    if abort then
      print "INIT: Bootstrap aborted!"
      abort = nil
      return
    end

    require "init-bootstrap"
  end
)
