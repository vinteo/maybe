# https://github.com/fawazahmed0/exchange-api
# No rate limits, free to use
# To use this provider, set environment var EXCHANGE_RATE_PROVIDER=exchange_api
class Provider::ExchangeApi < Provider
  include ExchangeRateConcept, SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::ExchangeApi::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  InvalidSecurityPriceError = Class.new(Error)

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/currency-api@#{date - 1.day}/v1/currencies/#{from.downcase}.json")
      rate = JSON.parse(response.body).dig(from.downcase, to.downcase)

      Rate.new(date: date.to_date, from:, to:, rate: rate)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      request_body = {}
      date = start_date
      while date <= end_date
        fetch_exchange_rate(from: from, to: to, date: date)
        date += 1.day
      end
    end
  end

  private
    attr_reader :api_key

    def base_url
      "https://cdn.jsdelivr.net/npm/@fawazahmed0"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.request :json
        faraday.response :raise_error
      end
    end
end
