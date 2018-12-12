# frozen_string_literal: true
require 'ostruct'

FactoryBot.define do
  factory :user, class: OpenStruct do

    email { 'ab12@sanger.ac.uk' }
    groups { ['world'] }

    initialize_with { new(attributes) }

  end
end