class AdminBootstrap
  def self.call(email:, name:)
    new(email:, name:).call
  end

  def initialize(email:, name:)
    @email = email
    @name = name
  end

  def call
    if email.blank?
      log("skipped: BOOTSTRAP_ADMIN_EMAIL unset")
      return
    end

    user = User.find_by(email: email)
    created = user.nil?
    user ||= User.create!(email:, password: Devise.friendly_token(32), terms_of_service: "1", confirmed_at: Time.current, **name_attributes)
    log(created ? "created user #{user.email}" : "found user #{user.email}")

    if user.admin?
      log("already admin #{user.email}")
    else
      Jumpstart.grant_system_admin!(user)
      log("granted admin #{user.email}")
    end

    user
  # AIDEV-NOTE: Deliberately broad rescue — this runs inside render.yaml's
  # startCommand/preDeployCommand chained with `&&`. A raise here would stop
  # the web service from booting on Render's free tier, which has no console
  # to recover from. Fail open (log and continue) rather than fail closed.
  rescue => error
    log("error: #{error.class}: #{error.message}", level: :error)
    nil
  end

  private

  attr_reader :email, :name

  def name_attributes
    first_name, last_name = normalized_name.split(" ", 2)
    {first_name:, last_name:}
  end

  def normalized_name
    name.to_s.squish.presence || "Cove Admin"
  end

  def log(message, level: :info)
    output = "[admin:bootstrap] #{message}"
    puts output
    Rails.logger.public_send(level, output)
  end
end
