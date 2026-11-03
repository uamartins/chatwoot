# frozen_string_literal: true

# uam: a caixa de sessão (pareada com um celular) não tem a janela de 24 h da Cloud API.
# Sem isso, a caixa native herda a regra da Cloud: o painel bloqueia a resposta e o envio cai
# no ramo de template e falha.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::Conversations::MessageWindowService
  private

  def messaging_window
    return if @conversation.inbox.channel_type == 'Channel::Whatsapp' && @conversation.inbox.channel.session_family?

    super
  end
end
