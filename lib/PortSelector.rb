class PortSelector < Trema::Controller
  @@Selectport = 2 
  def start(_args)
    logger.info 'PortSelector started.'
    puts "Select Port is ", @@Selectport
  end

  def switch_ready(datapath_id)
    send_flow_mod_add(
    datapath_id,
      priority: 100,
      match: Match.new(destination_mac_address: '01:80:C2:00:00:00') #Drop STP Flame
    )
    logger.info "Hello switch #{datapath_id.to_hex}!"
    send_message datapath_id, Features::Request.new
  end

  def packet_in(datapath_id, packet_in)
    logger.info "#{datapath_id.to_hex},flow_mod_set!"
    logger.info "パケットが来たポートは#{packet_in.in_port}"
    send_flow_mod_add(
      datapath_id,
      idle_timeout: 0,
      match: ExactMatch.new(packet_in),
      actions: SendOutPort.new(:flood)
    )
#    send_flow_mod_add(
#      datapath_id,
#      match: Match.new(ether_type: 0x0806), #ARP (dl_type: mo OK??)
#      actions: SendOutPort.new(@@Selectport) #:flood or portNum "2" "1" etc ...
#    )
    send_packet_out( #Packet_outはflowを設定する最初だけパケットがコントローラに行ってしまうので、それをhostに送り返す用
      datapath_id,
      raw_data: packet_in.raw_data,
      actions: SendOutPort.new(:flood)
    )
  end

  def features_reply datapath_id, message
    message.ports.each do | each |
      puts "Port no: #{ each.number }, name: #{ each.name }"
    end
  end

#  def port_status datapath_id, message
#    return if message.phy_port.state & Port::OFPPS_LINK_DOWN == 0
#    puts "Port #{ message.phy_port.number } is down."
#    send_flow_mod_delete(
#      datapath_id,
#      :match => Match.new,
#      :out_port => message.phy_port.number
#    )
#  end

end
