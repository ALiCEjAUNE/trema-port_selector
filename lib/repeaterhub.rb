class RepeaterHub < Trema::Controller
  def start(_args)
    logger.info 'Trema started.'
  end
  def switch_ready(datapath_id)
    logger.info "Hello #{datapath_id.to_hex}!"
  end
  def packet_in(datapath_id, packet_in)
    send_flow_mod_add(
      datapath_id,
      match: ExactMatch.new(packet_in),
      actions: SendOutPort.new(:flood)
    )
    send_packet_out(
      datapath_id,
      raw_data: packet_in.raw_data,
      actions: SendOutPort.new(:flood)
    )
  end
end
