# frozen_string_literal: true

# uam: trechos da integração native no canal WhatsApp, aplicados por prepend_mod_with.
#
# Os corpos vêm de app/models/channel/whatsapp.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT,
# Copyright (c) 2025-2026 FAZER.AI LTDA), só com os ramos que servem ao native: os de Baileys,
# Z-API e uazapi ficaram de fora.
#
# A cadeia fica [Whatsapp::Session::ChannelExtension, Custom::Channel::Whatsapp, Channel::Whatsapp],
# a mesma ordem da fazer.ai: a extensão responde pelos provedores de sessão e chama `super` aqui,
# e este módulo cai no oficial para os outros.
module Custom::Channel::Whatsapp # rubocop:disable Metrics/ModuleLength
  # Subconjunto do limite de conversas novas que a tela usa (ChannelExtension#update_account_limits!).
  NEW_CHAT_CAP_KEYS = %w[capping_status ote_status mv_status total_quota used_quota cycle_start_timestamp cycle_end_timestamp].freeze

  def self.prepended(base)
    base.prepend Whatsapp::Session::ChannelExtension
    base.before_destroy :disconnect_channel_provider, if: -> { provider_service.respond_to?(:disconnect_channel_provider) }

    base.delegate :setup_channel_provider, :import_session, :reassert_desired_state, :presence_subscribe,
                  :create_group, :update_group_subject, :update_group_description, :update_group_picture,
                  :update_group_participants, :group_invite_code, :revoke_group_invite, :group_join_requests,
                  :handle_group_join_requests, :group_leave, :group_setting_update, :group_join_approval_mode,
                  :group_member_add_mode, to: :provider_service
  end

  def supports_reactions?
    provider == 'whatsapp_cloud'
  end

  def use_internal_host?
    false
  end

  def update_provider_connection!(provider_connection)
    provider_connection ||= {}
    # Chaves em string, como o jsonb devolve, para um estado igual ser reconhecido e ignorado.
    normalized = provider_connection.deep_stringify_keys
    return if normalized == self.provider_connection

    previous_connection = self.provider_connection['connection']
    connection_changed = normalized['connection'] != previous_connection
    assign_attributes(provider_connection: normalized)
    # Sem validate_provider_config. Só a troca de `connection` toca a caixa (e invalida o cache
    # de caixas da conta); QR, erro e época mudam a cada poucos segundos e vão só pelo evento.
    if connection_changed
      save!(validate: false)
    else
      Inbox.no_touching { save!(validate: false) }
    end
    broadcast_provider_connection_updated(previous_connection)
  end

  def provider_connection_data
    data = provider_connection_agent_data
    data.merge!(provider_connection_admin_data) if Current.account_user&.administrator?
    data
  end

  # A metade que todo agente recebe, a mesma no REST e no push do cable.
  def provider_connection_agent_data(connection = provider_connection)
    {
      connection: connection['connection'],
      reachout_time_lock: connection['reachout_time_lock'].presence,
      new_chat_cap: connection['new_chat_cap'].presence,
      send_stall: connection['send_stall'].presence,
      rerouting: connection['rerouting'].presence
    }.compact
  end

  # A metade só de admin; o argumento é o retrato que está sendo mostrado.
  def provider_connection_admin_data(connection = provider_connection)
    { qr_data_url: connection['qr_data_url'], error: connection['error'] }
  end

  def toggle_typing_status(typing_status, conversation:)
    return unless provider_service.respond_to?(:toggle_typing_status)

    recipient_id = conversation.contact.identifier || conversation.contact.phone_number
    last_message = conversation.messages.last
    provider_service.toggle_typing_status(typing_status, last_message: last_message, recipient_id: recipient_id)
  end

  def update_presence(status)
    return unless provider_service.respond_to?(:update_presence)

    provider_service.update_presence(status)
  end

  def read_messages(messages, conversation:)
    return unless provider_service.respond_to?(:read_messages)
    # `mark_as_read` nil vale como true.
    return if provider_config&.dig('mark_as_read') == false

    recipient_id = conversation.contact.identifier || conversation.contact.phone_number
    # Marcado antes do envio: o provedor devolve esse recibo como entrada, e quem o lê não pode
    # tomá-lo por outro aparelho da conta abrindo a conversa (Whatsapp::SelfReadReceipts).
    Whatsapp::SelfReadReceipts.record(conversation, messages) if marker_read_back?
    provider_service.read_messages(messages, recipient_id: recipient_id)
  end

  def unread_conversation(conversation)
    return unless provider_service.respond_to?(:unread_message)

    last_message = conversation.messages.last
    provider_service.unread_message(conversation.contact.phone_number, last_message) if last_message
  end

  def disconnect_channel_provider
    provider_service.disconnect_channel_provider
  rescue StandardError => e
    # Um destroy não pode ser travado por um provedor que não solta; um disconnect explícito
    # é um operador esperando resposta. @session_teardown vem do before_destroy da extensão.
    raise unless @session_teardown

    Rails.logger.error "Failed to disconnect channel provider: #{e.message}"
  end

  def received_messages(messages, conversation)
    return unless provider_service.respond_to?(:received_messages)

    recipient_id = conversation.contact.identifier || conversation.contact.phone_number
    provider_service.received_messages(recipient_id, messages)
  end

  def on_whatsapp(phone_number, deadline: :provider)
    return unless provider_service.respond_to?(:on_whatsapp)

    provider_service.on_whatsapp(phone_number, deadline: deadline)
  end

  def delete_message(message, conversation:)
    return unless provider_service.respond_to?(:delete_message)

    recipient_id = conversation.contact.identifier || conversation.contact.phone_number
    return if recipient_id.blank?

    provider_service.delete_message(recipient_id, message)
  end

  def edit_message(message, new_content, conversation:)
    return unless provider_service.respond_to?(:edit_message)

    recipient_id = conversation.contact.identifier || conversation.contact.phone_number
    provider_service.edit_message(recipient_id, message, new_content)
  end

  def sync_group(conversation, soft: false)
    return unless provider_service.respond_to?(:sync_group)

    provider_service.sync_group(conversation, soft: soft)
  end

  def allow_group_creation?
    provider_service.respond_to?(:allow_group_creation?) && provider_service.allow_group_creation?
  end

  # Só os provedores de sessão leem de volta a marca do recibo próprio.
  def marker_read_back?
    session_provider?
  end

  private

  # Empurra o estado da conexão pelo websocket sem o dispatcher completo (que sempre enfileira
  # um EventDispatcherJob). Leva o `connection` anterior para o AgentBotListener separar a troca
  # rara de estado do vaivém de QR, erro e época.
  def broadcast_provider_connection_updated(previous_connection)
    return if inbox.blank?

    Rails.configuration.dispatcher.sync_dispatcher.dispatch(
      Events::Types::INBOX_PROVIDER_CONNECTION_UPDATED, Time.zone.now,
      inbox: inbox, provider_connection: provider_connection, previous_connection: previous_connection
    )
  end
end
