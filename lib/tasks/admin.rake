namespace :admin do
  desc "Creates the system admin named by BOOTSTRAP_ADMIN_EMAIL. Idempotent; no-ops when unset."
  task bootstrap: :environment do
    AdminBootstrap.call(email: ENV["BOOTSTRAP_ADMIN_EMAIL"], name: ENV["BOOTSTRAP_ADMIN_NAME"])
  end
end
