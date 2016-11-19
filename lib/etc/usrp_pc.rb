require "socket"

def wait waittime
    told = Time.now
    told_unix = told.to_i+(told.usec*(10**(-6)))
    begin
      t = Time.now
      t_unix = t.to_i+(t.usec*(10**(-6)))
      t_diff = t_unix.to_f-told_unix.to_f
    end while t_diff <= waittime.to_f
    return t_diff
end

udp = UDPSocket.open()
sockaddr = Socket.pack_sockaddr_in(50000, "192.168.0.241")

puts "Enter the time period.(0.001~ sec)"
interval = gets.chop
puts "interval #{interval} sec"

loop do
#  for i in 1..3 do
    i = rand(1..3)
    udp.send(i.to_s, 0, sockaddr)
#    puts i
    puts (i+1)

#    sleep(interval.to_f)

    wait(interval)
#  end
end

udp.close
