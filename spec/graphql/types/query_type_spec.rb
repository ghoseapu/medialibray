require "rails_helper"

RSpec.describe Types::QueryType do
    describe "items" do
        let!(:items) { create_pair(:item) }

        let(:query) do
            %(query {
                items {
                    title
                    user {
                        fullName
                    }
                }
            })
        end

        subject(:result) do
            ApuLibrarySchema.execute(query).as_json
        end

        it "returns all items" do
            expect(result.dig("data", "items")).to match_array(
                items.map { |item| { "title" => item.title } }
            )
        end
    end
end