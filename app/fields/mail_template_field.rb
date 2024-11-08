# frozen_string_literal: true

require "administrate/field/base"

class MailTemplateField < Administrate::Field::Base
  def name
    data.class::DISPLAYED_NAME
  end
end
