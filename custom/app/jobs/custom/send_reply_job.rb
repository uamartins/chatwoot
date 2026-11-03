# frozen_string_literal: true

# uam: tentativas do envio pela sessão do WhatsApp (native). Um erro da sessão tenta de novo
# (4 vezes); uma mensagem ainda em processamento em outro lugar espera 60 s (3 vezes). Esgotadas
# as tentativas, a mensagem termina failed com o motivo, em vez de ficar parada sem estado.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA). Sem o ramo de e-mail da fazer.ai.
module Custom::SendReplyJob
  def self.prepended(base)
    base.extend ClassMethods

    base.retry_on Whatsapp::Session::Errors::Error, wait: :polynomially_longer, attempts: 4 do |job, error|
      Rails.logger.error "SendReplyJob exhausted retries for message #{job.arguments.first}: #{error.message}"
      SendReplyJob.fail_message(job.arguments.first, error.message)
    end

    base.retry_on Whatsapp::Session::Errors::MessageAlreadyProcessing, wait: 60.seconds, attempts: 3 do |job, error|
      Rails.logger.error "SendReplyJob gave up on message #{job.arguments.first}: still processing elsewhere (#{error.message})"
      SendReplyJob.fail_message(job.arguments.first, I18n.t('errors.inboxes.channel.outgoing.still_processing'))
    end
  end

  module ClassMethods
    def fail_message(message_id, reason)
      message = Message.find_by(id: message_id)
      return if message.blank?
      return unless delivers_message?(message)

      Whatsapp::Session::Inbound::StatusTransition.fail_send(message, reason)
    rescue StandardError => e
      Rails.logger.error "SendReplyJob could not mark message #{message_id} as failed (#{reason}): #{e.class}: #{e.message}"
      raise
    end

    def delivers_message?(message)
      return false if SendReplyJob::CHANNEL_SERVICES[message.conversation.inbox.channel.class.to_s] == ::Messages::SendEmailNotificationService

      (message.outgoing? || message.template?) && !message.private? &&
        message.content_type != 'voice_call' && !(message.deleted? && !message.removed_reaction?)
    end
  end
end
