class MovingEstimateCalculator
  DISTANCE_TIERS = [
    { upper_bound_meters: 50_000, amount: 30_000 },
    { upper_bound_meters: 200_000, amount: 50_000 },
    { upper_bound_meters: 500_000, amount: 100_000 }
  ].freeze
  MAXIMUM_AMOUNT = 150_000

  def self.call(distance_meters)
    unless distance_meters.is_a?(Integer) && distance_meters.positive?
      raise ArgumentError, "distance_meters must be a positive integer"
    end

    tier = DISTANCE_TIERS.find { |candidate| distance_meters < candidate[:upper_bound_meters] }
    tier ? tier[:amount] : MAXIMUM_AMOUNT
  end
end
