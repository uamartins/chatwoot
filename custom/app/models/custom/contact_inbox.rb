# frozen_string_literal: true

# uam: trechos da integração native no contact_inbox, aplicados por prepend_mod_with.
#
# Vêm de app/models/contact_inbox.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c)
# 2025-2026 FAZER.AI LTDA): a marca de "número sem WhatsApp" (com o recibo recente que a desfaz)
# e a saída de um grupo, por caixa.
module Custom::ContactInbox
  WHATSAPP_MISSING_RECHECK_AFTER = 6.hours
  WHATSAPP_RECEIPT_MEMORY = 10.minutes

  def self.prepended(base)
    base.extend ClassMethods
    base.before_update -> { self.whatsapp_missing_checked_at = nil }, if: :will_save_change_to_contact_id?
    base.after_update_commit :broadcast_whatsapp_missing_change, if: :saved_change_to_whatsapp_missing_checked_at?
  end

  module ClassMethods
    # Guarda quando saiu a mensagem mais nova que um recibo confirmou, por contato e caixa, para
    # uma consulta de número que ainda esperava o provedor quando o recibo chegou.
    def remember_whatsapp_receipt(inbox_id, contact_id, sent_at)
      key = whatsapp_receipt_key(inbox_id, contact_id)
      Redis::Alfred.with do |conn|
        3.times do
          stored = conn.watch(key) do
            seen = conn.get(key)
            if seen.present? && seen.to_f >= sent_at.to_f
              conn.unwatch
              next :kept
            end

            conn.multi { |transaction| transaction.set(key, sent_at.to_f, ex: WHATSAPP_RECEIPT_MEMORY.to_i) }
          end
          break if stored
        end
      end
    end

    def whatsapp_receipt_key(inbox_id, contact_id)
      format(Redis::Alfred::WHATSAPP_RECEIPT_SEEN, inbox_id: inbox_id, contact_id: contact_id)
    end
  end

  def mark_whatsapp_missing_for!(phone, flag_before:, asked_at:)
    marked_at = with_whatsapp_answer_guard(phone, flag_before) do
      next if whatsapp_presence_since?(asked_at)

      update!(whatsapp_missing_checked_at: asked_at)
      whatsapp_missing_checked_at
    end
    return if marked_at.nil?

    ActiveRecord.after_all_transactions_commit do
      clear_whatsapp_missing_for!(phone, flag_before: marked_at) if whatsapp_presence_since?(asked_at)
    end
  end

  def clear_whatsapp_missing_for!(phone, flag_before:)
    with_whatsapp_answer_guard(phone, flag_before) { clear_whatsapp_missing! }
  end

  def with_whatsapp_answer_guard(phone, flag_before)
    contact.with_lock do
      lock!
      next unless contact.phone_number == phone && whatsapp_missing_checked_at == flag_before

      yield
    end
  end

  def whatsapp_presence_since?(time)
    whatsapp_receipt_since?(time) ||
      Message.incoming.where(conversation_id: Conversation.where(inbox_id: inbox_id, contact_id: contact_id).select(:id),
                             created_at: time.change(usec: 0)..).any? do |message|
        message.whatsapp_sent_at >= time
      end
  end

  def whatsapp_receipt_since?(time)
    seen = Redis::Alfred.get(self.class.whatsapp_receipt_key(inbox_id, contact_id))
    seen.present? && seen.to_f >= time.to_f
  end

  def clear_whatsapp_missing!
    return if whatsapp_missing_checked_at.nil?

    update!(whatsapp_missing_checked_at: nil)
  end

  def broadcast_whatsapp_missing_change
    conversations.find_each do |conversation|
      conversation.update_column(:updated_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
      Import::SilentWrite.wrap(announce: true) do
        conversation.dispatch_conversation_updated_event(broadcast_metadata: { source: 'whatsapp_missing' })
      end
    end
  end

  def whatsapp_missing_recheck_due?
    whatsapp_missing_checked_at.present? && whatsapp_missing_checked_at <= WHATSAPP_MISSING_RECHECK_AFTER.ago
  end

  def group_left? = group_left_at.present? || legacy_group_left?

  def mark_group_left!
    convert_legacy_group_left!
    return if group_left_at.present?

    update!(group_left_at: Time.current)
  end

  def mark_group_rejoined!
    convert_legacy_group_left!
    return if group_left_at.nil?

    update!(group_left_at: nil)
  end

  # Antes da coluna group_left_at, a saída ficava em additional_attributes do contato do grupo.
  def legacy_group_left? = contact.additional_attributes&.dig('group_left').present?

  def convert_legacy_group_left!
    return unless legacy_group_left?

    contact.with_lock do
      contact.contact_inboxes.where(group_left_at: nil).update_all(group_left_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      contact.update!(additional_attributes: (contact.additional_attributes || {}).except('group_left'))
    end
    reload
  end
end
