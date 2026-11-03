# frozen_string_literal: true

# uam: pushes do WhatsApp (native) pelo websocket.
# - inbox_provider_connection_updated: o estado da conexão; os agentes recebem a metade deles e
#   os admins também o QR e o erro;
# - conversation_recording: "gravando áudio", no mesmo formato do "digitando" do oficial;
# - contact_group_synced: o grupo com os membros depois de uma sincronização;
# - conversation_updated: leva os metadados do broadcast (a marca de número sem WhatsApp).
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA), sem as
# agendadas, os pins e a fatia de contato do presenter, que são recursos fora da F2.
module Custom::ActionCableListener
  def inbox_provider_connection_updated(event)
    inbox = event.data[:inbox]
    account = inbox.account
    provider_connection = event.data[:provider_connection] || {}

    connection = inbox.channel.provider_connection_agent_data(provider_connection)
    broadcast(account, account.agents.pluck(:pubsub_token), Events::Types::INBOX_PROVIDER_CONNECTION_UPDATED,
              { inbox_id: inbox.id, provider_connection: connection })
    broadcast(account, account.administrators.pluck(:pubsub_token), Events::Types::INBOX_PROVIDER_CONNECTION_UPDATED,
              { inbox_id: inbox.id,
                provider_connection: connection.merge(inbox.channel.provider_connection_admin_data(provider_connection)) })
  end

  def conversation_recording(event)
    conversation = event.data[:conversation]
    account = conversation.account
    user = event.data[:user]
    tokens = typing_event_listener_tokens(account, conversation, user)

    broadcast(
      account,
      tokens,
      Events::Types::CONVERSATION_RECORDING,
      conversation: conversation.push_event_data,
      user: user.push_event_data,
      is_private: event.data[:is_private] || false
    )
  end

  def conversation_updated(event)
    metadata = event.data[:broadcast_metadata]
    return super if metadata.blank?

    conversation, account = extract_conversation_and_account(event)
    tokens = user_tokens(account, conversation.inbox.members) + contact_inbox_tokens(conversation.contact_inbox)

    broadcast(account, tokens, Events::Types::CONVERSATION_UPDATED, conversation.push_event_data.merge(event_metadata: metadata))
  end

  def contact_group_synced(event)
    contact, account = extract_contact_and_account(event)
    channel = event.data[:channel] || contact.group_channel
    own_member = Whatsapp::Session::Owner.group_member(channel, contact)
    payload = contact.push_event_data.merge(
      group_members: group_members_data(contact),
      inbox_id: channel&.inbox&.id,
      inbox_phone_number: channel&.phone_number,
      own_member_id: own_member&.id,
      is_inbox_admin: own_member&.role == 'admin'
    )

    broadcast(account, [account_token(account)], Events::Types::CONTACT_GROUP_SYNCED, payload)
  end

  private

  def group_members_data(contact)
    GroupMember.active.where(group_contact: contact).includes(:contact).map do |member|
      {
        id: member.id, role: member.role, is_active: member.is_active, group_contact_id: member.group_contact_id,
        contact: { id: member.contact.id, name: member.contact.name, phone_number: member.contact.phone_number,
                   identifier: member.contact.identifier, thumbnail: member.contact.avatar_url }
      }
    end
  end
end
