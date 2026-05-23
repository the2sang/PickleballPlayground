require "rails_helper"

RSpec.describe User, type: :model do
  describe "codedash key" do
    it "generates a six-letter key when a user is created" do
      user = create(:user)

      expect(user.code_dash_key).to match(/\A[A-Z]{6}\z/)
      expect(user.code_dash_key_issued_at).to be_present
    end

    it "normalizes assigned keys" do
      user = create(:user, code_dash_key: "qr-s t uv")

      expect(user.code_dash_key).to eq("QRSTUV")
    end

    it "finds a user by a normalized key" do
      user = create(:user, code_dash_key: "QWERTY")

      expect(described_class.find_by_code_dash_key("qwe-rty")).to eq(user)
    end

    it "regenerates the key and clears last used time" do
      user = create(:user, code_dash_key: "ZXCVBN", code_dash_key_last_used_at: 1.day.ago)

      expect { user.regenerate_code_dash_key! }
        .to change { user.reload.code_dash_key }
        .from("ZXCVBN")
      expect(user.code_dash_key).to match(/\A[A-Z]{6}\z/)
      expect(user.code_dash_key_last_used_at).to be_nil
      expect(user.code_dash_key_issued_at).to be_present
    end
  end
end
