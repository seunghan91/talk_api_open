require 'rails_helper'

RSpec.describe Session, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "has_secure_token" do
    it "auto-generates a unique token on create" do
      session = create(:session)
      expect(session.token).to be_present
    end

    it "generates a string token" do
      session = create(:session)
      expect(session.token).to be_a(String)
    end

    it "generates unique tokens for different sessions" do
      session_a = create(:session)
      session_b = create(:session)
      expect(session_a.token).not_to eq(session_b.token)
    end

    it "generates a token with sufficient length" do
      session = create(:session)
      expect(session.token.length).to be >= 24
    end

    it "does not allow duplicate tokens at the database level" do
      session_a = create(:session)
      session_b = build(:session)
      session_b.token = session_a.token

      expect { session_b.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      session = build(:session)
      expect(session).to be_valid
    end

    it "requires a user" do
      session = build(:session, user: nil)
      expect(session).not_to be_valid
    end
  end

  describe ".active scope" do
    it "returns sessions active within the last 30 days" do
      active_session = create(:session, :active)
      expect(Session.active).to include(active_session)
    end

    it "excludes sessions older than 30 days" do
      expired_session = create(:session, :expired)
      expect(Session.active).not_to include(expired_session)
    end

    it "returns multiple active sessions" do
      sessions = create_list(:session, 3, last_active_at: 1.day.ago)
      expect(Session.active.count).to eq(3)
    end

    it "returns empty when no active sessions exist" do
      create(:session, :expired)
      expect(Session.active).to be_empty
    end
  end

  describe "#expired?" do
    it "returns true when last_active_at is more than 30 days ago" do
      session = create(:session, last_active_at: 31.days.ago)
      expect(session.expired?).to be true
    end

    it "returns false when last_active_at is less than 30 days ago" do
      session = create(:session, last_active_at: 29.days.ago)
      expect(session.expired?).to be false
    end

    it "returns false when last_active_at is exactly 30 days ago (boundary)" do
      freeze_time do
        session = create(:session, last_active_at: 30.days.ago)
        # 30.days.ago is NOT < 30.days.ago, so expired? returns false
        expect(session.expired?).to be false
      end
    end

    it "returns false when session was just created" do
      session = create(:session, last_active_at: Time.current)
      expect(session.expired?).to be false
    end

    it "returns true when last_active_at is far in the past" do
      session = create(:session, last_active_at: 1.year.ago)
      expect(session.expired?).to be true
    end
  end

  describe "#touch_last_active!" do
    it "updates last_active_at to the current time" do
      session = create(:session, last_active_at: 10.days.ago)

      freeze_time do
        session.touch_last_active!
        session.reload
        expect(session.last_active_at).to be_within(1.second).of(Time.current)
      end
    end

    it "extends the life of an expired session" do
      session = create(:session, :expired)
      expect(session.expired?).to be true

      session.touch_last_active!
      session.reload
      expect(session.expired?).to be false
    end

    it "uses update_column to skip callbacks and validations" do
      session = create(:session, last_active_at: 5.days.ago)
      original_updated_at = session.updated_at

      session.touch_last_active!
      session.reload

      # update_column does not modify updated_at
      expect(session.updated_at).to eq(original_updated_at)
    end

    it "makes the session appear in the active scope" do
      session = create(:session, :expired)
      expect(Session.active).not_to include(session)

      session.touch_last_active!
      expect(Session.active).to include(session)
    end
  end

  describe "dependent destroy through user" do
    it "destroys sessions when the user is destroyed" do
      user = create(:user)
      create_list(:session, 3, user: user)
      expect { user.destroy }.to change(Session, :count).by(-3)
    end

    it "does not destroy sessions belonging to other users" do
      user_a = create(:user)
      user_b = create(:user)
      create(:session, user: user_a)
      create(:session, user: user_b)

      expect { user_a.destroy }.to change(Session, :count).by(-1)
      expect(Session.where(user: user_b).count).to eq(1)
    end
  end

  describe "multiple sessions per user" do
    it "allows a user to have multiple active sessions" do
      user = create(:user)
      session_a = create(:session, user: user, user_agent: "Chrome")
      session_b = create(:session, user: user, user_agent: "Safari")
      session_c = create(:session, user: user, user_agent: "Firefox")

      expect(user.sessions.count).to eq(3)
      expect(user.sessions).to include(session_a, session_b, session_c)
    end

    it "allows a mix of active and expired sessions for the same user" do
      user = create(:user)
      active_session = create(:session, user: user, last_active_at: 1.day.ago)
      expired_session = create(:session, user: user, last_active_at: 31.days.ago)

      expect(user.sessions.count).to eq(2)
      expect(Session.active.where(user: user)).to include(active_session)
      expect(Session.active.where(user: user)).not_to include(expired_session)
    end

    it "generates distinct tokens for sessions of the same user" do
      user = create(:user)
      sessions = create_list(:session, 5, user: user)
      tokens = sessions.map(&:token)

      expect(tokens.uniq.size).to eq(5)
    end
  end

  describe "optional attributes" do
    it "can be created without ip_address" do
      session = create(:session, ip_address: nil)
      expect(session).to be_persisted
    end

    it "can be created without user_agent" do
      session = create(:session, user_agent: nil)
      expect(session).to be_persisted
    end

    it "stores ip_address and user_agent when provided" do
      session = create(:session, ip_address: "192.168.1.1", user_agent: "Mozilla/5.0")
      session.reload
      expect(session.ip_address).to eq("192.168.1.1")
      expect(session.user_agent).to eq("Mozilla/5.0")
    end
  end
end
