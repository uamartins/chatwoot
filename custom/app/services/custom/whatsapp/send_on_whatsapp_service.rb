# frozen_string_literal: true

# uam: envio de sessão (native) no WhatsApp.
# - O destinatário é o número do contato (só dígitos), não o source_id da Cloud API.
# - Erro da sessão: o que pode dar certo volta para o retry_on do SendReplyJob; o resto marca a
#   mensagem como failed na hora, com o motivo.
# - O source_id é gravado pela reserva do native; se o agente apagou a mensagem enquanto o job
#   esperava, a reserva manda revogar e a exclusão vai para o canal.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::Whatsapp::SendOnWhatsappService
  private

  def send_session_message
    return super unless channel.session_provider?

    message_id = channel.send_message(recipient_id, message)
    persist_source_id(message_id)
  rescue Whatsapp::Session::Errors::Error => e
    fail_unless_retryable(e)
  end

  def fail_unless_retryable(error)
    raise error if error.retryable?
    raise error if error.code == Whatsapp::Session::Errors::MessageAlreadyProcessing::CODE

    message.reload
    Whatsapp::Session::Inbound::StatusTransition.fail_send(message, error.message)
    nil
  end

  def persist_source_id(message_id)
    return if message_id.blank?
    return unless Whatsapp::Session::Outbound::SourceIdReservation.assign(message, { source_id: message_id }) == :revoke

    ::Messages::DeleteOnChannelJob.perform_later(message.id)
  end

  def recipient_id
    message.conversation.contact.phone_number&.gsub(/[^\d]/, '') || message.conversation.contact.identifier
  end
end
