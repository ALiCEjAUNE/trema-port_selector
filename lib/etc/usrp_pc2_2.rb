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

udp1 = UDPSocket.open()
udp2 = UDPSocket.open()
udp3 = UDPSocket.open()

sockaddr1 = Socket.pack_sockaddr_in(50000, "192.168.0.241")
sockaddr2 = Socket.pack_sockaddr_in(50001, "192.168.0.241")
sockaddr3 = Socket.pack_sockaddr_in(50002, "192.168.0.241")


puts "Enter the time period.(0.001~ sec)"
interval = gets.chop
puts "interval #{interval} sec"
i_old = 0

loop do

#  i = rand(1..3)
  for i in 1..3 do
    unless i == i_old then
      case i
      when 1 then
        udp1.send("", 0, sockaddr1)
      
      when 2 then
        udp2.send("", 0, sockaddr2)

      when 3 then
        udp3.send("", 0, sockaddr3)
      end
#      puts (i+1)
    else 
      puts "NO channel change"
    end
#    sleep(interval.to_f)
    i_old = i
    wait(interval)
  end
end

udp1.close
udp2.close
udp3.close
