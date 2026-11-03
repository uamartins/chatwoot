# frozen_string_literal: true

# uam: agenda a conferência periódica das sessões do WhatsApp (native) junto com os outros itens.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::TriggerScheduledItemsJob
  def perform
    super
    Whatsapp::Session::ConnectionCheckSchedulerJob.perform_later
  end
end
