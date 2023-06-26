require "json"
require "net/http"

class BankHolidayChecker
  def self.is_bank_holiday?
    uri = "https://www.gov.uk/bank-holidays.json"
    bank_holidays_data = JSON.parse(Net::HTTP.get(URI.parse(uri)))
    dates = bank_holidays_data["england-and-wales"]["events"].map { |e| e["date"] }
    dates.include? Time.now.strftime("%Y-%m-%d")
  end
end
