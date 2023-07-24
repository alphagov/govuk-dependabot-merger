require "timecop"
require_relative "../../lib/bank_holiday_checker"

RSpec.describe BankHolidayChecker do
  before do
    example_bank_holiday_data = {
      "england-and-wales": {
        "division": "england-and-wales",
        "events": [
          {
            "title": "New Year’s Day",
            "date": "2018-01-01",
            "notes": "",
            "bunting": true,
          },
          {
            "title": "Good Friday",
            "date": "2018-03-30",
            "notes": "",
            "bunting": false,
          },
        ],
      },
    }
    stub_request(:get, "https://www.gov.uk/bank-holidays.json")
      .to_return(status: 200, body: example_bank_holiday_data.to_json)
  end

  describe ".is_bank_holiday?" do
    it "should return true if today is a bank holiday" do
      bank_holiday_date = Time.local(2018, 0o3, 30, 10, 5, 0)
      Timecop.freeze(bank_holiday_date) do
        expect(BankHolidayChecker.is_bank_holiday?).to eq(true)
      end
    end

    it "should return false if today is not a bank holiday" do
      expect(BankHolidayChecker.is_bank_holiday?).to eq(false)
    end
  end
end
