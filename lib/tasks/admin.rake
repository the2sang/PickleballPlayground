namespace :admin do
  desc "Grant admin role to a user. Usage: bin/rails admin:grant EMAIL=user@example.com"
  task grant: :environment do
    email = ENV["EMAIL"].to_s.strip.downcase
    abort "EMAIL is required. Usage: bin/rails admin:grant EMAIL=user@example.com" if email.empty?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" unless user

    if user.role_admin?
      puts "Already admin: #{user.email_address}"
    else
      user.role_admin!
      puts "Granted admin to #{user.email_address}"
    end
  end

  desc "Revoke admin role. Usage: bin/rails admin:revoke EMAIL=user@example.com"
  task revoke: :environment do
    email = ENV["EMAIL"].to_s.strip.downcase
    abort "EMAIL is required. Usage: bin/rails admin:revoke EMAIL=user@example.com" if email.empty?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" unless user

    if user.role_user?
      puts "Already user: #{user.email_address}"
    else
      user.role_user!
      puts "Revoked admin from #{user.email_address}"
    end
  end
end
