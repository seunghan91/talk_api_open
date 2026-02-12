require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the Api::V1::AnnouncementsHelper. For example:
#
# describe Api::V1::AnnouncementsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe Api::V1::AnnouncementsHelper, type: :helper do
  it "has a basic example" do
    expect(true).to be(true)
  end
end
