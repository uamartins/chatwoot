# frozen_string_literal: true

# uam: uma gravação do navegador chega como `.ogg` marcado `audio/opus`; o WhatsApp só toca como
# nota de voz o que vem como `audio/ogg`. O download_url corrige o tipo do blob antes de entregar
# a URL, para o tipo anunciado ao conector e o do arquivo baixado serem o mesmo.
# Vem de app/models/attachment.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026
# FAZER.AI LTDA).
module Custom::Attachment
  def download_url
    return '' unless file.attached?

    normalize_opus_blob_content_type!
    super
  end

  def normalize_opus_blob_content_type!
    blob = file.blob
    return unless blob.content_type == 'audio/opus'

    blob.update!(content_type: 'audio/ogg')
  end
end
