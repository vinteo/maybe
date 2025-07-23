class Provider::OpenExchangeRates < Provider
  include ExchangeRateConcept, SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::OpenExchangeRates::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)

  def initialize(app_id)
    @app_id = app_id
  end

  def healthy?
    with_provider_response do
      response = client.get("#{base_url}/usage.json")
      JSON.parse(response.body).dig("status").casecmp?("active")
    end
  end

  def usage
    with_provider_response do
      response = client.get("#{base_url}/usage.json")

      parsed = JSON.parse(response.body)

      remaining = parsed.dig("data", "usage", "requests_remaining")
      limit = parsed.dig("data", "usage", "requests_quota")
      used = parsed.dig("data", "usage", "requests")

      UsageData.new(
        used: used,
        limit: limit,
        utilization: used / limit * 100,
        plan: parsed.dig("data", "plan", "name"),
      )
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/historical/#{date.to_s}.json") do |req|
        req.params["base"] = from
      end

      rates = JSON.parse(response.body).dig("rates")

      Rate.new(date: date.to_date, from:, to:, rate: rates.dig(to))
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      results = []
      current_date = start_date
      last_date = end_date

      while current_date <= last_date
        results.concat(fetch_exchange_rate(from: from, to: to, date: current_date))
        current_date += 1.day
      end

      return results
    end
  end


  private
    attr_reader :app_id

    def base_url
      ENV["OPEN_EXCHANGE_RATES_URL"] || "https://openexchangerates.org/api"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
        faraday.headers["Authorization"] = "Token #{app_id}"
      end
    end
end
