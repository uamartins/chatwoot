# frozen_string_literal: true

# uam: trechos da integração native no contato. O oficial aplica este módulo com
# include_mod_with('Concerns::Contact'), então ele é um concern e não sobrescreve método do
# Contact. Vem de app/models/contact.rb da fazer.ai (v4.19.0-fazer-ai.141, MIT, Copyright (c)
# 2025-2026 FAZER.AI LTDA): o tipo de grupo, os membros e a saída de grupo por caixa.
module Custom::Concerns::Contact
  extend ActiveSupport::Concern

  included do
    # Mescla em colunas JSON sob lock (consolidação de contatos e sincronização de grupos).
    include JsonColumnMerge

    has_many :group_memberships, class_name: 'GroupMember', foreign_key: :group_contact_id, dependent: :destroy,
                                 inverse_of: :group_contact
    has_many :group_member_contacts, through: :group_memberships, source: :contact
    has_many :group_participations, class_name: 'GroupMember', dependent: :destroy, inverse_of: :contact

    enum group_type: { individual: 0, group: 1 }, _prefix: true

    after_update_commit :forget_whatsapp_missing_answers, if: :saved_change_to_phone_number?
  end

  # O additional_attributes é uma coluna JSON com vários escritores: relê sob o lock da linha e
  # mescla, em vez de gravar um retrato tirado antes de uma chamada de rede (AvatarSync).
  def update_avatar_sync_markers!(remove: [], merge: {})
    with_lock do
      attributes = (additional_attributes || {}).except(*remove).merge(merge)
      next if attributes == additional_attributes

      # Sem validações, que falhariam nas checagens do arquivo de avatar.
      update_columns(additional_attributes: attributes) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def group_channel
    contact_inboxes.first&.inbox&.channel
  end

  def group_left_in?(inbox_id)
    return false if inbox_id.blank?

    contact_inboxes.find_by(inbox_id: inbox_id)&.group_left? || false
  end

  private

  # Um número novo invalida o que se sabia sobre o anterior.
  def forget_whatsapp_missing_answers
    contact_inboxes.where.not(whatsapp_missing_checked_at: nil).find_each(&:clear_whatsapp_missing!)
  end
end
