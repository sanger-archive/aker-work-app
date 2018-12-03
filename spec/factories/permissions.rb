FactoryBot.define do
  factory :permission do
    accessible { nil }
    permitted { "blackbeard@sanger.ac.uk" }
    r { false }
    w { false }
    x { false }
  end
end
