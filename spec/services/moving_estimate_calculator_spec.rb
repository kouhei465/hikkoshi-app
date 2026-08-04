require "rails_helper"

RSpec.describe MovingEstimateCalculator do
  describe ".call" do
    where = {
      1 => 30_000,
      49_999 => 30_000,
      50_000 => 50_000,
      199_999 => 50_000,
      200_000 => 100_000,
      499_999 => 100_000,
      500_000 => 150_000
    }

    where.each do |distance_meters, amount|
      it "#{distance_meters}mの場合は#{amount}円を返す" do
        expect(described_class.call(distance_meters)).to eq(amount)
      end
    end

    it "0mの場合はエラーにする" do
      expect { described_class.call(0) }.to raise_error(ArgumentError)
    end

    it "整数以外の場合はエラーにする" do
      expect { described_class.call(50_000.0) }.to raise_error(ArgumentError)
    end
  end
end
