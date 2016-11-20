require 'pio'

class PortSelector < Trema::Controller

#  @@portlist = Array(2..4)
  PORTLIST = Array(2..4)
  PORTLIST.freeze
#  @@switchlist = [0xabd,0x111]
  SWITCHLIST = [0xabd,0x111]
  SWITCHLIST.freeze
#  @@setport = @@portlist[rand(0..2)]
  @@setport = PORTLIST[rand(0..2)]


  def start(_args)
    logger.info 'PortSelector started.'
    puts "Selected port, #{PORTLIST}"
    puts "Switch List, #{SWITCHLIST}" 
  end

  def switch_ready(datapath_id)
    aliveport = @@setport
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"   
    ipv6_drop_flow(datapath_id)
    port_select_flow_ready(datapath_id,1,aliveport)
  end

  def packet_in(datapath_id, packet_in)
#   putlog(datapath_id,packet_in)   
   if packet_in.in_port == 5 then
    case packet_in.ether_type
    when 34525
      puts "IPv6,dropped. #{packet_in.ether_type}"
    when 2054
      case packet_in.data
      when Arp::Request
#        logger.info "ARP Request has arrived.#{packet_in.data}"
        arp_request = packet_in.data
        replydata = Arp::Reply.new(
                      destination_mac: arp_request.source_mac,
                      source_mac: 'dd:6c:4c:a9:7d:04',
                      sender_protocol_address: arp_request.target_protocol_address,
                      target_protocol_address: arp_request.sender_protocol_address
                    )
#       puts "replay is #{replydata}"
        send_packet_out(
          datapath_id,
          raw_data: replydata.to_binary,
          actions: SendOutPort.new(packet_in.in_port)
        )
      else
        puts "Not Arp::Request"
      end
    else       
#      rest = packet_in.rest[4..-1]
        oldport = @@setport
        aliveport = PORTLIST[rand(0..2)]
        case packet_in.transport_destination_port
        when 50000
          aliveport = PORTLIST[0]
        when 50001
          aliveport = PORTLIST[1]
        when 50002
          aliveport = PORTLIST[2]
        else
          logger.info "Port number is incorrect. Set random port."
        end
        @@setport = aliveport
        unless aliveport == oldport then
          port_select_flow(SWITCHLIST, 1,oldport,aliveport  )
        end
#        logger.info "aliveport is #{aliveport}"
    end
   end
  end
  
  def ipv6_drop_flow datapath_id
    send_flow_mod_add( datapath_id, priority: 100, match: Match.new(ether_type: 0x86dd))
  end
      
  def port_select_flow_ready datapath_id,host_port,set_port
      PORTLIST.each do |port|
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: port),
                         actions: SendOutPort.new(host_port))
      end
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         actions: SendOutPort.new(set_port))
      
  end

  def port_select_flow swid,host_port,old_port,set_port
        swid.each do |datapath_id|
          send_flow_mod_add( datapath_id,
                         priority: 1000,
                         match: Match.new(in_port: host_port,ether_type:0x0800 ),
                         actions: SendOutPort.new(old_port))
          send_flow_mod_add( datapath_id,
                         priority: 1000,
                         match: Match.new(in_port: host_port,ether_type:2054 ),
                         actions: SendOutPort.new(old_port))
        end
        swid.each do |datapath_id|
          send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         actions: SendOutPort.new(set_port))
        end
        delete_flow(swid,host_port,old_port)
  end

  def delete_flow swid,host_port,old_port
      swid.each do |datapath_id|
        send_flow_mod_delete( datapath_id, match: Match.new(in_port: host_port,ether_type:0x0800))
        send_flow_mod_delete( datapath_id, match: Match.new(in_port: host_port,ether_type:0x0806))
      end
  end
  
  def putlog datapath_id,packet_in
    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
    logger.info "パケットが来たポートは#{packet_in.in_port}"    
    logger.info "パケットの中身は#{packet_in.data}"
    logger.info "パケットの送信元macは#{packet_in.source_mac}"
    logger.info "パケットの種類は#{packet_in.ip_protocol}"
    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    logger.info"#{datapath_id.to_hex},#{packet_in.in_port},#{packet_in.ether_type} ar"
  end
end

