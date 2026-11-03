# frozen_string_literal: true

# uam: trechos da integração native na mensagem, aplicados por prepend_mod_with.
#
# Vêm de app/models/message.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026
# FAZER.AI LTDA): os atributos de conteúdo que o native grava (reação, edição, apagada pelo
# contato, id pendente...), os eventos de edição e de corpo recuperado, a marca de "número sem
# WhatsApp" que uma mensagem desfaz, e os pulos de reação nos callbacks (uma reação não é
# resposta, não reabre conversa e não muda o tempo de espera). Ficaram de fora as agendadas, o
# zapi_args e o reopen por time/bot, que são recursos da fazer.ai fora da F2.
module Custom::Message
  RECOVERED_BODY = 'recovered_body'

  NATIVE_CONTENT_ATTRIBUTES = %i[is_reaction is_edited previous_content referral rich deleted_by_contact
                                 pending_source_id edited_at is_masked is_view_once].freeze

  def self.prepended(base)
    base.attr_accessor :skip_message_flooding_validation, :defer_edit_announcement
    base.store_accessor :content_attributes, *NATIVE_CONTENT_ATTRIBUTES

    base.scope :hide_removed_reactions, lambda {
      json_path = "(content_attributes#>>'{}')::jsonb"
      where(
        "((#{json_path})->>'is_reaction' = 'true') IS NOT TRUE " \
        "OR (((#{json_path})->>'deleted' = 'true') IS NOT TRUE AND content IS NOT NULL AND content <> '')"
      )
    }

    base.after_commit :clear_whatsapp_missing_flag, on: [:create, :update], if: :proves_whatsapp_presence?
  end

  def reaction?
    ActiveModel::Type::Boolean.new.cast(content_attributes['is_reaction']) == true
  end

  def deleted?
    ActiveModel::Type::Boolean.new.cast(content_attributes['deleted']) == true
  end

  def removed_reaction?
    deleted? && content_attributes['is_reaction'].present?
  end

  # Grava sob lock, descartando antes uma mudança em content_attributes ainda não salva (ela
  # seria escrita por cima do que outro processo acabou de gravar).
  def update_under_lock!(attributes)
    restore_attributes(['content_attributes']) if content_attributes_changed?
    save! if changed?
    with_lock { update!(attributes) }
  end

  def valid_first_reply?
    return false if reaction?

    super
  end

  def announce_edit
    send_edited_event if edited_in_place?
  end

  def announce_restored_body
    announce_edit
    send_recovered_event if showing_recovered_body?
  end

  # Quando o WhatsApp diz que a mensagem foi enviada, arredondado para cima no segundo.
  def whatsapp_sent_at
    seconds = content_attributes&.dig('external_created_at').presence
    (seconds ? Time.zone.at(seconds.to_i) : created_at).change(usec: 999_999)
  end

  private

  def prevent_message_flooding
    return if skip_message_flooding_validation

    super
  end

  def clear_whatsapp_missing_flag
    return unless inbox.channel_type == 'Channel::Whatsapp'

    ContactInbox.remember_whatsapp_receipt(inbox_id, conversation.contact_id, created_at) if outgoing?
    flagged = ContactInbox.where(inbox_id: inbox_id, contact_id: conversation.contact_id)
                          .where(whatsapp_missing_checked_at: ...whatsapp_evidence_at)
    ids = flagged.pluck(:id)
    return if ids.empty?

    flagged.where(id: ids).update_all(whatsapp_missing_checked_at: nil) # rubocop:disable Rails/SkipsModelValidations
    conversation.reload_contact_inbox
    ContactInbox.where(id: ids).find_each(&:broadcast_whatsapp_missing_change)
  end

  def proves_whatsapp_presence?
    return incoming? if previously_new_record?

    outgoing? && saved_change_to_status? && (delivered? || read?) && !Import::SilentWrite.on?
  end

  def whatsapp_evidence_at = incoming? ? whatsapp_sent_at : created_at

  def set_waiting_since_on_incoming_message
    return if reaction?

    super
  end

  def human_response?
    return false if reaction?

    super
  end

  def dispatch_update_event
    super
    send_edited_event if edited_in_place? && !defer_edit_announcement
  end

  def edited_in_place?
    previous_changes.key?('content') && is_edited
  end

  def showing_recovered_body?
    digest = content_attributes.to_h[RECOVERED_BODY]

    digest.present? && digest == Digest::SHA256.hexdigest(content.to_s)
  end

  def send_recovered_event
    Rails.configuration.dispatcher.dispatch(Events::Types::MESSAGE_RECOVERED, Time.zone.now, message: self, content: content)
  end

  def send_edited_event
    Rails.configuration.dispatcher.dispatch(Events::Types::MESSAGE_EDITED, Time.zone.now, message: self, content: content,
                                                                                          performed_by: Current.executed_by,
                                                                                          previous_changes: previous_changes)
  end

  def reopen_conversation
    return if reaction?

    super
  end

  def mark_pending_conversation_as_open_for_human_response
    return if reaction?

    super
  end
end
