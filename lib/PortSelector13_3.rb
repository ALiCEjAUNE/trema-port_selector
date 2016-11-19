require 'pio'
#require_relative "pio-l4hdr"

class PortSelector < Trema::Controller

  @@portlist = Array(2..4)
  @@switchlist = [0xabd,0x111]
  @@setport = @@portlist[rand(0..2)]


  def start(_args)
    logger.info 'PortSelector started.'
    puts "Selected port, #{@@portlist}"
    puts "Switch List, #{@@switchlist}" 
  end

  def switch_ready(datapath_id)
    aliveport = @@setport
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"   
    ipv6_drop_flow(datapath_id)
    port_select_flow_ready(datapath_id,1,aliveport)
  end

  def packet_in(datapath_id, packet_in)
#    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
#    logger.info "パケットが来たポートは#{packet_in.in_port}"    
#    logger.info "パケットの中身は#{packet_in.data}"
#    logger.info "パケットの送信元macは#{packet_in.source_mac}"
#    logger.info "パケットの種類は#{packet_in.ip_protocol}"
#    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    

    case packet_in.ether_type
    when 34525
      puts "IPv6,dropped. #{packet_in.ether_type}"
    when 2054
      case packet_in.data
      when Arp::Request
        logger.info "ARP Request has arrived.#{packet_in.data}"
        arp_request = packet_in.data
#        puts "source_mac=#{arp_request.source_mac},target=#{arp_request.target_protocol_address},sender=#{arp_request.se$
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
#      rest = packet_in.rest[4..-2]
      rest = packet_in.rest[4..-1]
#      for num in 0..10
#        puts (-1*num)
#        puts packet_in.rest[num..-1]           
#      end
#      logger.info "ipv4パケット プロトコルは#{packet_in.ip_protocol}(6:TCP,17:UDP)"
      logger.info "パケットの中身は"
      puts rest
#      puts packet_in.rest
#      send_flow_mod_delete( datapath_id, match: Match.new() ) #すべてのフローを削除
      delete_flow( @@switchlist, 1, @@setport )
        aliveport = @@portlist[rand(0..2)]
        case rest.to_i
        when 1
          aliveport = @@portlist[0]
        when 2
          aliveport = @@portlist[1]
        when 3
          aliveport = @@portlist[2]
        else
          logger.info "Port number is incorrect. Set random port."
        end
        @@setport = aliveport
#        ipv6_drop_flow(datapath_id)
        port_select_flow( @@switchlist, 1, aliveport)
        logger.info "aliveport is #{aliveport}"
    end
  end
  
  def ipv6_drop_flow datapath_id
    send_flow_mod_add( datapath_id, priority: 100, match: Match.new(ether_type: 34525))
  end
  
  def delete_flow swid,host_port,now_port
      swid.each do |datapath_id|
        send_flow_mod_delete( datapath_id, match: Match.new(in_port: host_port))
        send_flow_mod_delete( datapath_id, match: Match.new(in_port: now_port))
      end
  end
      
  def port_select_flow_ready datapath_id,host_port,set_port
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port),
                         instructions: Apply.new(SendOutPort.new(set_port)))
        send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: set_port),
                         instructions: Apply.new(SendOutPort.new(host_port)))
        send_flow_mod_add( datapath_id,
                         match: Match.new(in_port: 5, ether_type: 0x0800 ),  #port5のみpacket_inを受付
                         instructions: Apply.new(SendOutPort.new(:controller)))
  end


  def port_select_flow swid,host_port,set_port
        swid.each do |datapath_id|
          send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: host_port), 
                         instructions: Apply.new(SendOutPort.new(set_port)))
          send_flow_mod_add( datapath_id,
                         priority: 10,
                         match: Match.new(in_port: set_port),
                         instructions: Apply.new(SendOutPort.new(host_port)))
        end 
  end
end
