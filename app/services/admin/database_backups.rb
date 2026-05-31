module Admin
  module DatabaseBackups
    DEFAULT_BACKUP_ROOT = Rails.root.join("storage", "db_backups")

    class << self
      def backup_root
        @backup_root || DEFAULT_BACKUP_ROOT
      end

      attr_writer :backup_root
    end
  end
end
