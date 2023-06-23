require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

def set_up_mock_token
  ENV["AUTO_MERGE_TOKEN"] = "some-value"
end
