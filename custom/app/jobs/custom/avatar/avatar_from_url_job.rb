# frozen_string_literal: true

# uam: foto de perfil vinda do WhatsApp (native).
# - resolved_at: quando quem chamou obteve a URL. Uma remoção registrada depois disso
#   (AvatarSync::REMOVED_AT) faz da URL uma foto que o contato já tirou, e o job não a põe de volta.
# - As marcas de sincronização vão por update_avatar_sync_markers!, que relê sob lock e mescla,
#   em vez de gravar um retrato do additional_attributes tirado antes do download.
# Vem da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c) 2025-2026 FAZER.AI LTDA).
module Custom::Avatar::AvatarFromUrlJob
  def perform(avatarable, avatar_url, resolved_at: nil)
    return if superseded?(avatarable, resolved_at)

    super(avatarable, avatar_url)
  end

  private

  def superseded?(avatarable, resolved_at)
    return false if resolved_at.blank? || !avatarable.is_a?(Contact)

    removed_at = (avatarable.additional_attributes || {})[Whatsapp::Session::AvatarSync::REMOVED_AT]
    return false if removed_at.blank?

    Time.zone.parse(removed_at) > Time.zone.parse(resolved_at)
  end

  def update_avatar_sync_attributes(avatarable, avatar_url)
    return unless avatarable.is_a?(Contact)
    return if avatar_url.blank?

    avatarable.update_avatar_sync_markers!(
      merge: { 'last_avatar_sync_at' => Time.current.iso8601, 'avatar_url_hash' => generate_url_hash(avatar_url) }
    )
  end
end
