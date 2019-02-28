# frozen_string_literal: true

require "rails_helper"

RSpec.describe "approve.css" do
  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  it "fetches the CSS file" do
    get "/approve/public/approve.css"

    expect(last_response).to be_ok
    expect(last_response.body).to be_include(".approve_pagination_block {")
  end
end
