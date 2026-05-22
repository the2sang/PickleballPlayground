module Users
  class FetchDuprRatingService
    DUPR_API_BASE = "https://backend.mydupr.com"

    Result = Struct.new(:success?, :rating, :error, keyword_init: true)

    def self.call(dupr_id:) = new(dupr_id:).call

    def initialize(dupr_id:)
      @dupr_id = dupr_id
    end

    def call
      bearer_token = ENV["DUPR_BEARER_TOKEN"] || Rails.application.credentials.dig(:dupr, :bearer_token)
      return Result.new(success?: false, error: "DUPR API 토큰이 설정되지 않았습니다.") if bearer_token.blank?

      uri = URI("#{DUPR_API_BASE}/player/v1.0/search")
      uri.query = URI.encode_www_form(query: @dupr_id, pageSize: 1)

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{bearer_token}"
      req["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }

      unless response.is_a?(Net::HTTPSuccess)
        return Result.new(success?: false, error: "DUPR API 오류 (#{response.code})")
      end

      parse_rating(JSON.parse(response.body))
    rescue => e
      Rails.logger.error("[FetchDuprRatingService] #{e.class}: #{e.message}")
      Result.new(success?: false, error: "DUPR 연동 중 오류가 발생했습니다.")
    end

    private

    def parse_rating(body)
      players = body.dig("result", "hits") || body["result"] || []
      return Result.new(success?: false, error: "DUPR ID를 찾을 수 없습니다.") if players.empty?

      player = players.first
      doubles = player["ratings"]&.dig("doubles", "displayRating")
      singles = player["ratings"]&.dig("singles", "displayRating")
      rating  = doubles || singles || player["rating"]

      return Result.new(success?: false, error: "DUPR 레이팅 정보를 가져올 수 없습니다.") if rating.blank?

      Result.new(success?: true, rating: { doubles: doubles&.to_f, singles: singles&.to_f })
    end
  end
end
