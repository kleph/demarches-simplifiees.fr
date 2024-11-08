# frozen_string_literal: true

class Instructeurs::FilterButtonsComponent < ApplicationComponent
  def initialize(filters:, procedure_presentation:, statut:)
    @filters = filters
    @procedure_presentation = procedure_presentation
    @statut = statut
  end

  def call
    safe_join(filters_by_family, ' et ')
  end

  private

  def filters_by_family
    @filters
      .group_by { _1.column.id }
      .values
      .map { |group| group.map { |f| filter_form(f) } }
      .map { |group| safe_join(group, ' ou ') }
  end

  def filter_form(filter)
    form_with(model: [:instructeur, @procedure_presentation], class: 'inline') do
      safe_join([
        hidden_field_tag('filters[]', ''),    # to ensure the filters is not empty
        *other_hidden_fields(filter),         # other filters to keep
        hidden_field_tag('statut', @statut),  # collection to set
        button_tag(button_content(filter), class: 'fr-tag fr-tag--dismiss fr-my-1w')
      ])
    end
  end

  def other_hidden_fields(filter)
    @filters.reject { _1 == filter }.flat_map do |f|
      [
        hidden_field_tag("filters[][id]", f.column.id),
        hidden_field_tag("filters[][filter]", f.filter)
      ]
    end
  end

  def button_content(filter)
    "#{filter.label.truncate(50)} : #{human_value(filter)}"
  end

  def human_value(filter_column)
    column, filter = filter_column.column, filter_column.filter

    if column.type_de_champ?
      find_type_de_champ(column.stable_id).dynamic_type.filter_to_human(filter)
    elsif column.dossier_state?
      if filter == 'pending_correction'
        Dossier.human_attribute_name("pending_correction.for_instructeur")
      else
        Dossier.human_attribute_name("state.#{filter}")
      end
    elsif column.groupe_instructeur?
      current_instructeur.groupe_instructeurs
        .find { _1.id == filter.to_i }&.label || filter
    elsif column.dossier_labels?
      Label.find(filter)&.name || filter
    elsif column.type == :date
      helpers.try_parse_format_date(filter)
    else
      filter
    end
  end

  def find_type_de_champ(stable_id)
    TypeDeChamp
      .joins(:revision_types_de_champ)
      .where(revision_types_de_champ: { revision_id: @procedure_presentation.procedure.revisions })
      .order(created_at: :desc)
      .find_by(stable_id:)
  end
end
