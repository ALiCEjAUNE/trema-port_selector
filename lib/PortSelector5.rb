require 'pio'

class PortSelector < Trema::Controller

  @@portlist = Array(1..3)
  @@aliveport_init = rand(1..3)
  def start(_args)
    logger.info 'PortSelector started.'
    puts "Select Port is #{@@portlist}"
  end

  def switch_ready(datapath_id)
    aliveport = @@aliveport_init
    logger.info "Hello switch #{datapath_id.to_hex}!"
    logger.info "aliveport is #{aliveport}"

    send_message datapath_id, Features::Request.new
    
#    send_flow_mod_add(datapath_id, math: Match.new(ether_type: 34525)) #ipv6(0x86dd or 34525) DROP 
    send_flow_mod_add( datapath_id, match: Match.new(in_port: 1), actions: SendOutPort.new(aliveport) )
    send_flow_mod_add( datapath_id, match: Match.new(in_port: aliveport), actions: SendOutPort.new(1) )
  end

  def packet_in(datapath_id, packet_in)
    logger.info "スイッチ#{datapath_id.to_hex}にフローエントリに該当しないパケットが到来"
    logger.info "パケットが来たポートは#{packet_in.in_port}"    
#    logger.info "パケットの中身は#{packet_in.data}"
    logger.info "パケットの送信元macは#{packet_in.source_mac}"
#    logger.info "パケットの種類は#{packet_in.ip_protocol}"
#    logger.info "パケットの宛先ポートは#{packet_in.transport_destination_port}"
    

    unless packet_in.ether_type == 34525 then
      puts "パケットの種類は#{packet_in.ether_type}"
      unless packet_in.ether_type == 2054 then
        puts "ipv4パケット プロトコルは #{packet_in.ip_protocol}(6:TCP,17:UDP)"
        if packet_in.source_ip_address == '192.168.0.4' then
          send_flow_mod_delete( datapath_id, match: Match.new() ) #すべてのフローを削除
          aliveport = rand(1..3)
          if packet_in.transport_destination_port == 50001 then
            aliveport = 1
          elsif packet_in.transport_destination_port == 50002 then
            aliveport = 2
          elsif packet_in.transport_destination_port == 50003 then
            aliveport = 3
          else
            logger.info "Port number is incorrect. Set random port."
          end
          send_flow_mod_add( datapath_id, match: Match.new(in_port: 1), actions: SendOutPort.new(aliveport) )
          send_flow_mod_add( datapath_id, match: Match.new(in_port: aliveport), actions: SendOutPort.new(1) )
          puts "aliveport is #{aliveport}"
        end
      else
        puts "Oops! ARP! #{packet_in.data}"
        case packet_in.data
        when Arp::Request
          puts "ARP Request is arrived"
          arp_request = packet_in.data
          puts "source_mac=#{arp_request.source_mac},target=#{arp_request.target_protocol_address},sender=#{arp_request.sender_protocol_address}"
          replydata = Arp::Reply.new(
                        destination_mac: arp_request.source_mac,
                        source_mac: 'dd:6c:4c:a9:7d:04',
                        sender_protocol_address: arp_request.target_protocol_address,
                        target_protocol_address: arp_request.sender_protocol_address
                      )
          puts "replay is #{replydata}"

          send_packet_out(
            datapath_id,
            raw_data: replydata.to_binary,
            actions: SendOutPort.new(packet_in.in_port)
          )
        else
          puts "ERROR"
        end
      end
    else
      puts "fuckin,ipv6! #{packet_in.ether_type}"
    end
      
#    send_packet_out( #Packet_outはflowを設定する最初だけパケットがコントローラに行ってしまうので、それをhostに送り返す用
#      datapath_id,
#      raw_data: packet_in.raw_data
#    )
  end

  def features_reply datapath_id, message
    message.ports.each do | each |
      puts "Port no: #{ each.number }, name: #{ each.name }"
    end
  end

end
