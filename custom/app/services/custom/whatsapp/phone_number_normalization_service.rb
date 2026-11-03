# frozen_string_literal: true

# uam: os outros números, em e164, sob os quais a pessoa deste número já pode estar cadastrada
# (variações do nono dígito etc.), para o ContactResolver do native achar o contato existente.
# O número exato fica de fora: quem chama passa ele como phone_number, que é tentado primeiro.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::Whatsapp::PhoneNumberNormalizationService
  def alternate_contact_phone_numbers(number)
    return [] if number.blank?

    phone_number_candidates(number.delete_prefix('+')).drop(1).map { |candidate| "+#{candidate}" }
  end
end
