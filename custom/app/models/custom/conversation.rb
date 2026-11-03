# frozen_string_literal: true

# uam: trechos da integração native na conversa, aplicados por prepend_mod_with.
# Vêm de app/models/conversation.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c)
# 2025-2026 FAZER.AI LTDA): o tipo de grupo e os metadados de broadcast no evento de conversa
# atualizada (a marca de número sem WhatsApp avisa a tela por ele).
module Custom::Conversation
  def self.prepended(base)
    base.enum group_type: { individual: 0, group: 1 }, _prefix: true
  end

  def dispatch_conversation_updated_event(previous_changes = nil, broadcast_metadata: nil)
    dispatcher_dispatch(Events::Types::CONVERSATION_UPDATED, previous_changes, broadcast_metadata: broadcast_metadata)
  end

  private

  def dispatcher_dispatch(event_name, changed_attributes = nil, broadcast_metadata: nil)
    payload = { conversation: self, notifiable_assignee_change: notifiable_assignee_change?,
                changed_attributes: changed_attributes, performed_by: Current.executed_by }
    payload[:broadcast_metadata] = broadcast_metadata unless broadcast_metadata.nil?
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, **payload)
  end
end
