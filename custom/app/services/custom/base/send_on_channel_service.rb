# frozen_string_literal: true

# uam: uma mensagem apagada antes de o job rodar não pode chegar ao contato: o conteúdo já é o
# marcador de apagada e os anexos já foram embora. Uma reação removida é a exceção (ela vai, para
# tirar a reação do outro lado; ver Message#removed_reaction?).
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::Base::SendOnChannelService
  private

  def invalid_message?
    super || (message.deleted? && !message.removed_reaction?)
  end
end
