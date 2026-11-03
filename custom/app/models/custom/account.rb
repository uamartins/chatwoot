# frozen_string_literal: true

# uam: chave por conta do provedor de sessão native, aplicada por prepend_mod_with.
# Vem de app/models/concerns/account_whatsapp_providers.rb da fazer.ai (v4.19.0-fazer-ai.141,
# MIT, Copyright (c) 2025-2026 FAZER.AI LTDA), sem a chave do uazapi. O native fica disponível
# para toda conta; `whatsapp_native_disabled` (no jsonb `settings`, por console) o tira de uma.
module Custom::Account
  def self.prepended(base)
    base.store_accessor :settings, :whatsapp_native_disabled
  end

  # O cast fica porque uma linha de console pode digitar "1".
  def whatsapp_native_disabled=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def whatsapp_session_provider_enabled?(provider)
    provider.to_s == 'native' && !whatsapp_native_disabled
  end
end
